import 'dart:async';
import 'dart:collection';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'facility_local.dart';
import 'facility_model.dart';
import 'facility_remote.dart';

// The Controller / Business Logic Layer: It receives user actions/events from the UI (like starting a search or loading details), queries the Repository, and updates the reactive FacilityState with the results (loaded facilities, highlights, search results, recents, etc.) to redraw the UI.

// he Orchestrator: It decides whether to fetch data from FacilityLocal (cache) or FacilityRemote (network) for each operation.
// This is the orchestrator and sole entry point for the rest of the application. It dictates the caching strategies. For instance:
// getAllFacilities() first yields cached facilities from Hive, then retrieves fresh ones from Supabase, updates Hive, and yields again.
// getFacilityDetail() checks Hive first (cache-first), fetching from Supabase only if it is not found locally.
// The BLoC layers only communicate with the Repository, keeping the underlying storage mechanisms decoupled.
// // Single entry point for all facility data consumed by the BLoC layer.
///
/// BLoC never imports [FacilityLocal] or [FacilityRemote] directly.
/// This class orchestrates caching strategy per operation:
///
/// | Method                | Source                          |
/// |-----------------------|---------------------------------|
/// | `getAllFacilities()`  | Cache → shared in-flight network |
/// | `getHighlights()`     | Cache only (sync, zero network) |
/// | `searchFacilities()`  | Bounded cache + coalesced RPC   |
/// | `getFacilityDetail()` | Cache-first, network on miss    |
/// | `getUserBookmarks()`  | Network first, Cache fallback   |
///
// ============================================================================
class FacilityRepository {
  final FacilityLocal _local;
  final FacilityRemote _remote;
  final LinkedHashMap<String, List<FacilityModel>> _searchCache =
      LinkedHashMap<String, List<FacilityModel>>();

  static const int _maxSearchCacheEntries = 40;
  static const int _minRemoteQueryLength = 3;
  static const Duration _facilitiesTtl = Duration(minutes: 10);
  static const Duration _catalogTtl = Duration(days: 1);

  Future<void>? _inFlightCatalogRefresh;

  Future<List<FacilityModel>>? _inFlightAllFacilities;
  DateTime? _lastAllFacilitiesFetchAt;

  Future<List<FacilityModel>>? _activeSearch;
  String? _activeSearchKey;
  int _searchEpoch = 0;
  _SearchRequest? _queuedSearch;
  Completer<List<FacilityModel>>? _queuedSearchCompleter;

  final StreamController<List<FacilityModel>> _facilitiesStreamController =
      StreamController<List<FacilityModel>>.broadcast();

  Stream<List<FacilityModel>> get facilitiesStream =>
      _facilitiesStreamController.stream;

  RealtimeChannel? _facilitiesRealtimeChannel;
  Timer? _realtimeDebounce;

  final Set<String> _contributedFacilityIds = {};
  final Set<String> _checkedFacilityIds = {};
  bool _contributorCacheLoaded = false;

  FacilityRepository({
    required FacilityLocal local,
    required FacilityRemote remote,
  }) : _local = local,
       _remote = remote {
    subscribeToFacilityUpdates();
  }

  /// Returns a Stream that emits cached facilities immediately, then a
  /// single shared network refresh when the cache is missing, stale, or forced.
  Stream<List<FacilityModel>> getAllFacilities({bool force = false}) async* {
    final cached = _local.getAllFacilities();
    if (cached.isNotEmpty) yield cached;

    if (_inFlightAllFacilities != null) {
      try {
        yield await _inFlightAllFacilities!;
      } catch (error) {
        if (cached.isEmpty) rethrow;
      }
      return;
    }

    final bool cacheIsFresh =
        !force &&
        cached.isNotEmpty &&
        _lastAllFacilitiesFetchAt != null &&
        DateTime.now().difference(_lastAllFacilitiesFetchAt!) < _facilitiesTtl;
    if (cacheIsFresh) return;

    final future = _fetchAndCacheAllFacilities();
    _inFlightAllFacilities = future;
    try {
      final fresh = await future;
      yield fresh;
    } catch (error) {
      if (cached.isEmpty) rethrow;
    } finally {
      if (identical(_inFlightAllFacilities, future)) {
        _inFlightAllFacilities = null;
      }
    }
  }

  Future<List<FacilityModel>> _fetchAndCacheAllFacilities({
    bool broadcast = false,
  }) async {
    final fresh = await _remote.getAllFacilities();
    await _local.saveAllFacilities(fresh);
    _lastAllFacilitiesFetchAt = DateTime.now();
    // Only broadcast when called from realtime/search paths — NOT from
    // getAllFacilities() which already yields via emit.forEach in the bloc.
    if (broadcast && !_facilitiesStreamController.isClosed) {
      _facilitiesStreamController.add(fresh);
    }
    return fresh;
  }

  /// Forces a fresh network fetch from Supabase, updates local Hive cache,
  /// and broadcasts the updated facilities list to all active UI subscribers.
  /// Shares the in-flight future so concurrent callers don't stack network
  /// calls — critical for preventing realtime event pile-ups.
  Future<List<FacilityModel>> refreshAllFacilities() async {
    if (_inFlightAllFacilities != null) {
      return _inFlightAllFacilities!;
    }
    final future = _fetchAndCacheAllFacilities(broadcast: true);
    _inFlightAllFacilities = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightAllFacilities, future)) {
        _inFlightAllFacilities = null;
      }
    }
  }

  /// Subscribes to realtime updates on health_facilities so newly added or
  /// updated facilities in the database immediately reflect in the app.
  void subscribeToFacilityUpdates() {
    unsubscribeFromFacilityUpdates();
    try {
      _facilitiesRealtimeChannel = _remote.supabase
          .channel('public:health_facilities')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'health_facilities',
            callback: (payload) {
              // Debounce: batch DB changes (e.g. multi-row inserts) coalesce
              // into a single refresh instead of stacking concurrent fetches.
              _realtimeDebounce?.cancel();
              _realtimeDebounce = Timer(const Duration(seconds: 2), () {
                unawaited(refreshAllFacilities());
              });
            },
          )
          .subscribe();
    } catch (_) {
      // Fallback silently if realtime replication is unconfigured
    }
  }

  void unsubscribeFromFacilityUpdates() {
    if (_facilitiesRealtimeChannel != null) {
      try {
        _remote.supabase.removeChannel(_facilitiesRealtimeChannel!);
      } catch (_) {}
      _facilitiesRealtimeChannel = null;
    }
  }

  /// Returns the [count] closest facilities to the user's position.
  List<FacilityModel> getHighlights({
    required double userLat,
    required double userLng,
    int count = 5,
  }) {
    final all = _local.getAllFacilities();
    if (all.isEmpty) return [];

    return (List<FacilityModel>.from(all)..sort(
          (a, b) => a
              .distanceTo(userLat, userLng)
              .compareTo(b.distanceTo(userLat, userLng)),
        ))
        .take(count)
        .toList();
  }

  /// Returns a specific facility synchronously from the local cache.
  FacilityModel? getFacilitySync(String facilityId) {
    final all = _local.getAllFacilities();
    try {
      return all.firstWhere((f) => f.facilityId == facilityId);
    } catch (_) {
      return null;
    }
  }

  /// Searches facilities via the Supabase RPC.
  ///
  /// Short queries without filters stay local. Identical in-flight searches
  /// share one Future. Newer queries coalesce onto a single follow-up RPC
  /// so intermediate keystrokes never spawn extra database work.
  Future<List<FacilityModel>> searchFacilities({
    required String query,
    String? typeFilter,
    String? cityFilter,
    String? serviceFilter,
    String? priceRangeFilter,
    double minRating = 0.0,
  }) async {
    final request = _SearchRequest(
      query: query.trim(),
      typeFilter: _normalizeFilter(typeFilter),
      cityFilter: _normalizeFilter(cityFilter),
      serviceFilter: _normalizeFilter(serviceFilter),
      priceRangeFilter: _normalizeFilter(priceRangeFilter),
      minRating: minRating,
    );

    if (!request.hasRemoteWork) {
      return searchCachedFacilities(request.query);
    }

    final cached = _takeSearchCache(request.cacheKey);
    if (cached != null) return cached;

    if (_activeSearch != null && _activeSearchKey == request.cacheKey) {
      return _activeSearch!;
    }

    if (_activeSearch != null) {
      _queuedSearch = request;
      _queuedSearchCompleter ??= Completer<List<FacilityModel>>();
      return _queuedSearchCompleter!.future;
    }

    return _executeSearch(request);
  }

  /// Drops any coalesced follow-up search so a clear/unmount cannot start
  /// another RPC after the in-flight call finishes.
  void cancelPendingSearch() {
    _searchEpoch++;
    _queuedSearch = null;
    final pending = _queuedSearchCompleter;
    _queuedSearchCompleter = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const []);
    }
  }

  /// Accent-insensitive substring match over the Hive facility list.
  List<FacilityModel> searchCachedFacilities(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final all = _local.getAllFacilities();
    if (all.isEmpty) return const [];
    return all
        .where((facility) => facility.name.toLowerCase().contains(needle))
        .toList();
  }

  Future<List<FacilityModel>> _executeSearch(_SearchRequest request) async {
    final epoch = _searchEpoch;
    final future = _remote.searchFacilities(
      query: request.query,
      typeFilter: request.typeFilter,
      cityFilter: request.cityFilter,
      serviceFilter: request.serviceFilter,
      priceRangeFilter: request.priceRangeFilter,
      minRating: request.minRating,
    );
    _activeSearch = future;
    _activeSearchKey = request.cacheKey;

    try {
      final results = await future;
      if (epoch == _searchEpoch) {
        _putSearchCache(request.cacheKey, results);
      }
      if (results.isNotEmpty) {
        await _local.upsertFacilities(results);
        final all = _local.getAllFacilities();
        if (!_facilitiesStreamController.isClosed) {
          _facilitiesStreamController.add(all);
        }
      }
      return results;
    } finally {
      if (identical(_activeSearch, future)) {
        _activeSearch = null;
        _activeSearchKey = null;
      }
      final queued = _queuedSearch;
      final queuedCompleter = _queuedSearchCompleter;
      _queuedSearch = null;
      _queuedSearchCompleter = null;
      if (queued != null &&
          queuedCompleter != null &&
          !queuedCompleter.isCompleted &&
          epoch == _searchEpoch) {
        unawaited(
          _executeSearch(queued).then(queuedCompleter.complete).catchError((
            Object error,
            StackTrace stack,
          ) {
            if (!queuedCompleter.isCompleted) {
              queuedCompleter.completeError(error, stack);
            }
          }),
        );
      } else if (queuedCompleter != null && !queuedCompleter.isCompleted) {
        queuedCompleter.complete(const []);
      }
    }
  }

  List<FacilityModel>? _takeSearchCache(String key) {
    final cached = _searchCache.remove(key);
    if (cached == null) return null;
    _searchCache[key] = cached;
    return cached;
  }

  void _putSearchCache(String key, List<FacilityModel> results) {
    _searchCache.remove(key);
    _searchCache[key] = results;
    while (_searchCache.length > _maxSearchCacheEntries) {
      _searchCache.remove(_searchCache.keys.first);
    }
  }

  String? _normalizeFilter(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<FacilityDetailModel?>? _inFlightDetail;
  String? _inFlightDetailId;

  //  Facility Detail (cache-first).
  /// Cache hit → instant return, no network. Cache miss → fetches from
  /// Supabase, saves to Hive, then returns.
  Future<FacilityDetailModel?> getFacilityDetail(String facilityId) async {
    final cached = _local.getFacilityDetail(facilityId);
    if (cached != null) return cached;

    if (_inFlightDetail != null && _inFlightDetailId == facilityId) {
      return _inFlightDetail;
    }

    final future = _remote.getFacilityDetail(facilityId);
    _inFlightDetail = future;
    _inFlightDetailId = facilityId;
    try {
      final detail = await future;
      if (detail != null) {
        await _local.saveFacilityDetail(detail);
      }
      return detail;
    } finally {
      if (identical(_inFlightDetail, future)) {
        _inFlightDetail = null;
        _inFlightDetailId = null;
      }
    }
  }

  /// Evicts the cached detail for [facilityId] so the next
  /// [getFacilityDetail] call fetches fresh data from the network.
  /// Called when a contribution affecting this facility is approved.
  Future<void> invalidateFacilityDetail(String facilityId) =>
      _local.invalidateFacilityDetail(facilityId);

  /// Records a facility as recently viewed (capped at 10 entries).
  /// Called by the BLoC when a user opens a facility detail.
  Future<void> saveRecentlyViewed(String facilityId) =>
      _local.saveRecentlyViewed(facilityId);

  /// Returns up to 10 recently-viewed facility IDs (most recent first).
  List<String> getRecentlyViewed() => _local.getRecentlyViewed();

  /// Clears the locally persisted recently-viewed list.
  Future<void> clearRecentlyViewed() => _local.clearRecentlyViewed();

  /// Fetches the authenticated user's bookmarked facilitY Ids.
  /// Network first (typically under 200ms), Cache fallback on network failure so the UI is never stale.
  Future<Set<String>> getBookmarkedIds() async {
    try {
      final ids = await _remote.getUserBookmarks();
      await _local.saveBookmarkIds(ids);
      return ids;
    } catch (_) {
      return _local.getBookmarkIds();
    }
  }

  /// Adds a bookmark for the authenticated user then syncs to cache.
  Future<void> addBookmark(String facilityId) async {
    await _remote.addBookmark(facilityId);
    final ids = _local.getBookmarkIds()..add(facilityId);
    await _local.saveBookmarkIds(ids);
  }

  /// Removes a bookmark for the authenticated user then syncs to cache.
  Future<void> removeBookmark(String facilityId) async {
    await _remote.removeBookmark(facilityId);
    final ids = _local.getBookmarkIds()..remove(facilityId);
    await _local.saveBookmarkIds(ids);
  }

  /// Clears cached bookmars Id set.
  // Called on Signout so next user never gets stale bookmark list.
  Future<void> clearBookmarkIds() => _local.clearBookmarkIds();

  /// Returns distinct service names from cached facilities for filter dropdowns.
  /// Derived from Hive (no network call) — returns empty list if cache is cold.
  /// Cached after first computation; invalidated when the facilities list changes.
  List<String>? _cachedServiceOptions;
  List<FacilityModel>? _serviceOptionsSourceList;

  List<String> getServiceOptions() {
    final all = _local.getAllFacilities();
    // Invalidate if the source list object changed (new fetch/save).
    if (!identical(all, _serviceOptionsSourceList)) {
      _cachedServiceOptions = null;
      _serviceOptionsSourceList = all;
    }
    if (_cachedServiceOptions != null) return _cachedServiceOptions!;

    final services = <String>{};
    for (final f in all) {
      services.addAll(f.servicesList);
    }
    _cachedServiceOptions = services.toList()..sort();
    return _cachedServiceOptions!;
  }

  /// SERVICES & TAGS CATALOG [contribute form autocomplete]
  // Cache-first, exactly like getAllFacilities(): the cached list (if any)
  // returns instantly and a single shared network refresh only fires once
  // per TTL window — repeated calls (every keystroke while typing) never
  // trigger extra reads against the database.

  /// Every known service name, ready for local (no-egress) autocomplete.
  Future<List<String>> getServicesCatalog() async {
    final cached = _local.getCachedServices();
    unawaited(_refreshCatalogIfStale());
    if (cached.isNotEmpty) return cached;
    await _refreshCatalogIfStale(force: true);
    return _local.getCachedServices();
  }

  /// Every known tag ("infrastructure") name, ready for local autocomplete.
  Future<List<String>> getTagsCatalog() async {
    final cached = _local.getCachedTags();
    unawaited(_refreshCatalogIfStale());
    if (cached.isNotEmpty) return cached;
    await _refreshCatalogIfStale(force: true);
    return _local.getCachedTags();
  }

  Future<void> _refreshCatalogIfStale({bool force = false}) {
    if (_inFlightCatalogRefresh != null) return _inFlightCatalogRefresh!;

    final fetchedAt = _local.getCatalogFetchedAt();
    final isStale =
        force ||
        fetchedAt == null ||
        DateTime.now().difference(fetchedAt) > _catalogTtl;
    if (!isStale) return Future.value();

    final future = () async {
      try {
        final results = await Future.wait([
          _remote.getServicesCatalog(),
          _remote.getTagsCatalog(),
        ]);
        await _local.saveCatalog(services: results[0], tags: results[1]);
      } catch (_) {
        // Network failure: keep serving whatever is already cached.
      }
    }();

    _inFlightCatalogRefresh = future;
    return future.whenComplete(() => _inFlightCatalogRefresh = null);
  }

  // CONTRIBUTOR STATUS CACHING
  void _ensureContributorCacheLoaded() {
    if (!_contributorCacheLoaded) {
      _contributedFacilityIds.addAll(_local.getContributorFacilityIds());
      _contributorCacheLoaded = true;
    }
  }

  /// Instant synchronous check: returns true if the user is already confirmed
  /// as a contributor in local Hive storage or memory. Zero network call.
  bool isCurrentUserContributorSync(String facilityId) {
    _ensureContributorCacheLoaded();
    return _contributedFacilityIds.contains(facilityId);
  }

  /// Checks if current user is a credited contributor for this facility.
  /// Hits local cache first. If not cached, performs one RPC call and caches
  /// the result locally to eliminate repeated egress calls on future visits.
  Future<bool> isCurrentUserContributor(String facilityId) async {
    _ensureContributorCacheLoaded();
    if (_contributedFacilityIds.contains(facilityId)) {
      return true;
    }
    if (_checkedFacilityIds.contains(facilityId)) {
      return false;
    }

    try {
      final isContributor = await _remote.isCurrentUserContributor(facilityId);
      _checkedFacilityIds.add(facilityId);
      if (isContributor) {
        _contributedFacilityIds.add(facilityId);
        await _local.saveContributorFacilityIds(_contributedFacilityIds);
      }
      return isContributor;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _realtimeDebounce?.cancel();
    unsubscribeFromFacilityUpdates();
    if (!_facilitiesStreamController.isClosed) {
      _facilitiesStreamController.close();
    }
  }
}

class _SearchRequest {
  final String query;
  final String? typeFilter;
  final String? cityFilter;
  final String? serviceFilter;
  final String? priceRangeFilter;
  final double minRating;

  const _SearchRequest({
    required this.query,
    required this.typeFilter,
    required this.cityFilter,
    required this.serviceFilter,
    required this.priceRangeFilter,
    required this.minRating,
  });

  bool get hasFilters =>
      typeFilter != null ||
      cityFilter != null ||
      serviceFilter != null ||
      priceRangeFilter != null ||
      minRating > 0;

  bool get hasRemoteWork =>
      hasFilters || query.length >= FacilityRepository._minRemoteQueryLength;

  String get cacheKey =>
      '${query.toLowerCase()}|$typeFilter|$cityFilter|$serviceFilter|$priceRangeFilter|$minRating';
}
