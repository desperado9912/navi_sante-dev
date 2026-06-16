import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'facility_model.dart';

// Handles caching for all facilities data in BLoC model. 
/// No business logic — just storage mechanics. The repository calls this;

// ── Hive Box Names ───────────────────────────────────────────────────────────
const String _facilitiesBox = 'facilities';
const String _detailsBox = 'facility_details';
const String _recentlyViewedBox = 'recently_viewed';

/// Key for the single entry that holds the full facility list.
const String _allFacilitiesKey = 'all';

/// Key for the recently-viewed facility ID list.
const String _recentlyViewedKey = 'recent';

/// Maximum number of recently-viewed entries kept in Hive.
const int _maxRecentlyViewed = 10;

// ── FacilityLocal ────────────────────────────────────────────────────────────
/// Owns all Hive read/write operations for facility data.
/// No business logic — just storage mechanics. The repository calls this;
/// nothing else in the codebase touches Hive directly for facility data.
/// JSON-encoded strings storage instead of TypeAdapters.
class FacilityLocal {
  /// Opens all facility Hive boxes.
  static Future<void> init() async {
    await Future.wait([
      Hive.openBox<String>(_facilitiesBox),
      Hive.openBox<String>(_detailsBox),
      Hive.openBox<String>(_recentlyViewedBox),
    ]);
  }

  // ── Facilities List ──────────────────────────────────────────────────────
  /// Overwrites the cached facility list with [facilities].
  Future<void> saveAllFacilities(List<FacilityModel> facilities) async {
    final box = Hive.box<String>(_facilitiesBox);
    final encoded = jsonEncode(facilities.map((f) => f.toJson()).toList());
    await box.put(_allFacilitiesKey, encoded);
  }

  /// Returns the cached facility list, or an empty list if the cache is cold.
  List<FacilityModel> getAllFacilities() {
    final box = Hive.box<String>(_facilitiesBox);
    final encoded = box.get(_allFacilitiesKey);
    if (encoded == null) return [];

    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((e) => FacilityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Whether at least one facility list has been cached.
  bool hasFacilities() {
    return Hive.box<String>(_facilitiesBox).containsKey(_allFacilitiesKey);
  }

  /// Caches a single facility's full detail payload, keyed by its ID.
  Future<void> saveFacilityDetail(FacilityDetailModel detail) async {
    final box = Hive.box<String>(_detailsBox);
    await box.put(detail.facilityId, jsonEncode(detail.toJson()));
  }

  /// Returns the cached detail for [facilityId], or `null` on a miss.
  FacilityDetailModel? getFacilityDetail(String facilityId) {
    final box = Hive.box<String>(_detailsBox);
    final encoded = box.get(facilityId);
    if (encoded == null) return null;

    return FacilityDetailModel.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
  }

  // ── Recently Viewed ────────────────────────────────────────────────────
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

  // ── Cache Management ─────────────────────────────────────────────────────
  /// Wipes all cached facility data. The next `getAllFacilities()` stream
  /// emission will fetch fresh from Supabase.
  Future<void> clearAll() async {
    await Future.wait([
      Hive.box<String>(_facilitiesBox).clear(),
      Hive.box<String>(_detailsBox).clear(),
      Hive.box<String>(_recentlyViewedBox).clear(),
    ]);
  }
}
