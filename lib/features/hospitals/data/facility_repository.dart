import 'facility_local.dart';
import '../controller/facility_model.dart';
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
/// | `getAllFacilities()`  | Cache → Network (Stream×2)      |
/// | `getHighlights()`     | Cache only (sync, zero network) |
/// | `searchFacilities()`  | Network only (never cached)     |
/// | `getFacilityDetail()` | Cache-first, network on miss    |
/// | `getUserBookmarks()`  | Network first, Cache fallback   |
///
// ============================================================================
class FacilityRepository {
  final FacilityLocal _local;
  final FacilityRemote _remote;
  final Map<String, List<FacilityModel>> _searchCache = {};

  FacilityRepository({
    required FacilityLocal local,
    required FacilityRemote remote,
  }) : _local = local,
       _remote = remote;

  /// Returns a Stream that emits up to twice: from Hive cache then from Supabase
  Stream<List<FacilityModel>> getAllFacilities() async* {
    final cached = _local.getAllFacilities();
    if (cached.isNotEmpty) yield cached;

    try {
      final fresh = await _remote.getAllFacilities();
      await _local.saveAllFacilities(fresh);
      yield fresh;
    } catch (error) {
      if (cached.isEmpty) rethrow;
      // Cache was already served — swallow the network error.
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

  /// Searches facilities via the Supabase RPC. Always network.
  Future<List<FacilityModel>> searchFacilities({
    required String query,
    String? typeFilter,
    String? cityFilter,
    String? serviceFilter,
    String? priceRangeFilter,
    double minRating = 0.0,
  }) async {
    final cacheKey =
        '$query-$typeFilter-$cityFilter-$serviceFilter-$priceRangeFilter-$minRating';
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    final results = await _remote.searchFacilities(
      query: query,
      typeFilter: typeFilter,
      cityFilter: cityFilter,
      serviceFilter: serviceFilter,
      priceRangeFilter: priceRangeFilter,
      minRating: minRating,
    );

    _searchCache[cacheKey] = results;
    return results;
  }

  //  Facility Detail (cache-first).
  /// Cache hit → instant return, no network. Cache miss → fetches from
  /// Supabase, saves to Hive, then returns.
  Future<FacilityDetailModel?> getFacilityDetail(String facilityId) async {
    final cached = _local.getFacilityDetail(facilityId);
    if (cached != null) return cached;

    final detail = await _remote.getFacilityDetail(facilityId);
    if (detail != null) {
      await _local.saveFacilityDetail(detail);
    }
    return detail;
  }

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
  Future<void> removeBookmark(String facilityId) async{
    await _remote.removeBookmark(facilityId);
    final ids = _local.getBookmarkIds()..remove(facilityId);
    await _local.saveBookmarkIds(ids);
  }

  /// Clears cached bookmars Id set. 
  // Called on Signout so next user never gets stale bookmark list.
  Future<void> clearBookmarkIds() => _local.clearBookmarkIds();

  /// Returns distinct service names from cached facilities for filter dropdowns.
  /// Derived from Hive (no network call) — returns empty list if cache is cold.
  List<String> getServiceOptions() {
    final all = _local.getAllFacilities();
    final services = <String>{};
    for (final f in all) {
      services.addAll(f.servicesList);
    }
    return services.toList()..sort();
  }
}
