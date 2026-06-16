import 'facility_get_local.dart';
import 'facility_model.dart';
import 'facility_get_remote.dart';

// Single entry point for all facility data consumed by the BLoC layer.
///
/// BLoC never imports [FacilityLocal] or [FacilityRemote] directly.
/// This class orchestrates caching strategy per operation:
///
/// | Method                | Source                          |
/// |-----------------------|---------------------------------|
/// | `getAllFacilities()`  | Cache → Network (Stream×2)     |
/// | `getHighlights()`     | Cache only (sync, zero network) |
/// | `searchFacilities()`  | Network only (never cached)     |
/// | `getFacilityDetail()` | Cache-first, network on miss    |
/// | `getUserBookmarks()`  | Network only                    |
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

  /// Searches facilities via the Supabase RPC.
  Future<List<FacilityModel>> searchFacilities({
    required String query,
    String? typeFilter,
    String? cityFilter,
    double minRating = 0.0,
  }) async {
    final cacheKey = '$query-$typeFilter-$cityFilter-$minRating';
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    final results = await _remote.searchFacilities(
      query: query,
      typeFilter: typeFilter,
      cityFilter: cityFilter,
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

  /// Fetches the authenticated user's bookmarked facilities.
  Future<List<FacilityModel>> getUserBookmarks() => _remote.getUserBookmarks();

  /// Adds a bookmark for the authenticated user.
  Future<void> addBookmark(String facilityId) =>
      _remote.addBookmark(facilityId);

  /// Removes a bookmark for the authenticated user.
  Future<void> removeBookmark(String facilityId) =>
      _remote.removeBookmark(facilityId);
}
