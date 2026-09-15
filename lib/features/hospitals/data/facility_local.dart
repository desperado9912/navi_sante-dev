import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../controller/facility_model.dart';

// Rename to facility_cache_manager.

// The local data manager for facility data.
/// Owns all Hive read/write operations for facility data.
/// JSON-encoded strings storage instead of TypeAdapters.
/// All operations, searches, queries, data, bookmarks etc
/// that are to be read or written to HIVE only are handled here, NO NETWORK CALLS.
/// No business logic — just storage mechanics. The repository calls this;

// Initilizes a hive box for the data.
const String _facilitiesBox = 'facilities';
const String _detailsBox = 'facility_details';
const String _recentlyViewedBox = 'recently_viewed';
const String _bookmarkedFacilitiesBox = 'bookmarks';
// const String _bookmarksBox = 'bookmarks';

/// Key for the single entry that holds the full facility list.
const String _allFacilitiesKey = 'all';

/// Key for the recently-viewed facility ID list.
const String _recentlyViewedKey = 'recent';

/// Key for the bookmarked facility IDs list.
const String _bookmarkIdsKey = 'bookmark_ids';

/// Maximum number of recently-viewed entries kept in Hive.
const int _maxRecentlyViewed = 10;


class FacilityLocal {
  // In-memory cache — avoids re-parsing the full JSON blob on every read.
  // Invalidated only by saveAllFacilities() and clearAll().
  List<FacilityModel>? _cachedFacilities;

  // In-memory cache for detail models (keyed by facilityId).
  // Additive — new details are inserted without evicting existing ones,
  // so subsequently added facility details remain accessible.
  final Map<String, FacilityDetailModel> _detailCache = {};

  // Opens all facility related Hive boxes.
  static Future<void> init() async {
    await Future.wait([
      Hive.openBox<String>(_facilitiesBox),
      Hive.openBox<String>(_detailsBox),
      Hive.openBox<String>(_recentlyViewedBox),
      Hive.openBox<String>(_bookmarkedFacilitiesBox),
    ]);
  }

  // FACILITIES HIVE BOX
  // Overwrites the cached facility list with [facilities].
  Future<void> saveAllFacilities(List<FacilityModel> facilities) async {
    _cachedFacilities = facilities;
    final box = Hive.box<String>(_facilitiesBox);
    final encoded = jsonEncode(facilities.map((f) => f.toJson()).toList());
    await box.put(_allFacilitiesKey, encoded);
  }

  // Returns the cached facility list, or an empty list if the cache is cold.
  List<FacilityModel> getAllFacilities() {
    if (_cachedFacilities != null) return _cachedFacilities!;

    final box = Hive.box<String>(_facilitiesBox);
    final encoded = box.get(_allFacilitiesKey);
    if (encoded == null) return [];

    final decoded = jsonDecode(encoded) as List<dynamic>;
    _cachedFacilities = decoded
        .map((e) => FacilityModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedFacilities!;
  }

  bool hasFacilities() {
    return _cachedFacilities != null ||
        Hive.box<String>(_facilitiesBox).containsKey(_allFacilitiesKey);
  }

  // Caches a single facility's full detail payload, keyed by its ID.
  Future<void> saveFacilityDetail(FacilityDetailModel detail) async {
    _detailCache[detail.facilityId] = detail;
    final box = Hive.box<String>(_detailsBox);
    await box.put(detail.facilityId, jsonEncode(detail.toJson()));
  }

  /// Returns the cached detail for [facilityId], or `null` on a miss.
  FacilityDetailModel? getFacilityDetail(String facilityId) {
    // Check in-memory cache first (instant).
    final memoryCached = _detailCache[facilityId];
    if (memoryCached != null) return memoryCached;

    // Fall back to Hive.
    final box = Hive.box<String>(_detailsBox);
    final encoded = box.get(facilityId);
    if (encoded == null) return null;

    final detail = FacilityDetailModel.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    _detailCache[facilityId] = detail;
    return detail;
  }

  // RECENTLY VIEWED FACILITIES HIVE BOX
  /// Records [facilityId] as the most-recently-viewed facility.
  /// Maintains a capped list of [_maxRecentlyViewed] IDs. If the ID already
  /// exists it is moved to the front (most recent). Oldest entries are
  /// evicted when the cap is exceeded.
  Future<void> saveRecentlyViewed(String facilityId) async {
    final box = Hive.box<String>(_recentlyViewedBox);
    final encoded = box.get(_recentlyViewedKey);

    final List<String> ids = encoded != null
        ? (jsonDecode(encoded) as List<dynamic>).cast<String>()
        : [];

    // Remove duplicate then prepend.
    ids.remove(facilityId);
    ids.insert(0, facilityId);

    // Cap the list.
    if (ids.length > _maxRecentlyViewed) {
      ids.removeRange(_maxRecentlyViewed, ids.length);
    }

    await box.put(_recentlyViewedKey, jsonEncode(ids));
  }

  /// Returns the last ≤10 recently-viewed facility IDs (most recent first).
  List<String> getRecentlyViewed() {
    final box = Hive.box<String>(_recentlyViewedBox);
    final encoded = box.get(_recentlyViewedKey);
    if (encoded == null) return [];

    return (jsonDecode(encoded) as List<dynamic>).cast<String>();
  }

  /// Clears only the recently-viewed list.
  Future<void> clearRecentlyViewed() async {
    await Hive.box<String>(_recentlyViewedBox).delete(_recentlyViewedKey);
  }

  // BOOKMARKED FACILITIES HIVE
  /// Persists the full set of bookmarked facility IDs.
  /// Overwrites any previous cache — call after every successful sync
  /// with the server (login fetch, or after a confirmed add/remove).
  Future<void> saveBookmarkIds(Set<String> ids) async {
    final box = Hive.box<String>(_bookmarkedFacilitiesBox);
    await box.put(_bookmarkIdsKey, jsonEncode(ids.toList()));
  }

  // Returns the cached set of bookmark IDs or empty set.
  // Used as offline fallback when network fetch fails.
  Set<String> getBookmarkIds() {
    final box = Hive.box<String>(_bookmarkedFacilitiesBox);
    final encoded = box.get(_bookmarkIdsKey);
    if (encoded == null) return {};
    return (jsonDecode(encoded) as List<dynamic>).cast<String>().toSet();
  }
  
  // Clears the cached bookmarks list. 
  // Called on sign out so the next user never sees a stale bookmark list.
  Future<void> clearBookmarkIds() async {
    await Hive.box<String>(_bookmarkedFacilitiesBox).delete(_bookmarkIdsKey);
  }


  // Cache Management: wipes all cached facility data for storage.
  /// The next [getAllFacilities] emission will fetch fresh from database.
  Future<void> clearAll() async {
    _cachedFacilities = null;
    _detailCache.clear();
    await Future.wait([
      Hive.box<String>(_facilitiesBox).clear(),
      Hive.box<String>(_detailsBox).clear(),
      Hive.box<String>(_recentlyViewedBox).clear(),
      Hive.box<String>(_bookmarkedFacilitiesBox).clear(),
    ]);
  }
}
