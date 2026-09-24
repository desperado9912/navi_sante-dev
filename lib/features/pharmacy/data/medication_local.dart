import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'pharmacy_model.dart';

// Owns all Hive read/write operations for medication data. JSON-encoded
// strings storage, same approach as FacilityLocal. No network calls —
// the repository decides when to call this vs. MedicationRemote.

const String _medicationsBox = 'medications';
const String _recentSearchesBox = 'medication_recent_searches';
const String _favouritesBox = 'medication_favourites';

const String _allMedicationsKey = 'all';
const String _quickFiltersKey = 'quick_filters';
const String _recentSearchesKey = 'recent';
const String _favouriteIdsKey = 'favourite_ids';

/// Capped at 5 per your spec — recent searches are meant to be a short,
/// glanceable row of chips, not a history log.
const int _maxRecentSearches = 5;

class MedicationLocal {
  // In-memory cache — avoids re-parsing the full JSON blob on every read.
  // Invalidated only by saveAllMedications() and clearAll().
  List<MedicationModel>? _cachedMedications;

  // Opens all medication-related Hive boxes.
  static Future<void> init() async {
    await Future.wait([
      Hive.openBox<String>(_medicationsBox),
      Hive.openBox<String>(_recentSearchesBox),
      Hive.openBox<String>(_favouritesBox),
    ]);
  }

  // MEDICATIONS
  Future<void> saveAllMedications(List<MedicationModel> medications) async {
    _cachedMedications = medications;
    final box = Hive.box<String>(_medicationsBox);
    final encoded = jsonEncode(medications.map((m) => m.toJson()).toList());
    await box.put(_allMedicationsKey, encoded);
  }

  List<MedicationModel> getAllMedications() {
    if (_cachedMedications != null) return _cachedMedications!;

    final box = Hive.box<String>(_medicationsBox);
    final encoded = box.get(_allMedicationsKey);
    if (encoded == null) return [];

    final decoded = jsonDecode(encoded) as List<dynamic>;
    _cachedMedications = decoded
        .map((e) => MedicationModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cachedMedications!;
  }

  // QUICK FILTERS — tiny, rarely changing list of condition names.
  Future<void> saveQuickFilters(List<String> filters) async {
    final box = Hive.box<String>(_medicationsBox);
    await box.put(_quickFiltersKey, jsonEncode(filters));
  }

  List<String> getQuickFilters() {
    final box = Hive.box<String>(_medicationsBox);
    final encoded = box.get(_quickFiltersKey);
    if (encoded == null) return [];
    return (jsonDecode(encoded) as List<dynamic>).cast<String>();
  }

  // RECENT SEARCHES
  /// Records [term] as a recent search. Filters out fragments (< 3 chars),
  /// removes shorter prefixes and caps the list at [_maxRecentSearches].
  Future<void> addRecentSearch(String rawTerm) async {
    final String term = rawTerm.trim();
    if (term.length < 3) return;

    final box = Hive.box<String>(_recentSearchesBox);
    final encoded = box.get(_recentSearchesKey);
    final List<String> terms = encoded != null
        ? (jsonDecode(encoded) as List<dynamic>).cast<String>()
        : [];

    final String lower = term.toLowerCase();

    // If an existing term already starts with this term and is longer,
    // don't add the shorter fragment (e.g. don't add "ibu" if "ibuprofen" exists).
    if (terms.any((t) => t.toLowerCase().startsWith(lower) && t.length > term.length)) {
      return;
    }

    // Remove any exact match or existing shorter prefixes (e.g. remove "ibu" when "ibuprofen" is added).
    terms.removeWhere((t) {
      final String tLower = t.toLowerCase();
      return tLower == lower || lower.startsWith(tLower);
    });

    terms.insert(0, term);

    if (terms.length > _maxRecentSearches) {
      terms.removeRange(_maxRecentSearches, terms.length);
    }
    await box.put(_recentSearchesKey, jsonEncode(terms));
  }

  List<String> getRecentSearches() {
    final box = Hive.box<String>(_recentSearchesBox);
    final encoded = box.get(_recentSearchesKey);
    if (encoded == null) return [];
    return (jsonDecode(encoded) as List<dynamic>).cast<String>();
  }

  Future<void> clearRecentSearches() async {
    await Hive.box<String>(_recentSearchesBox).delete(_recentSearchesKey);
  }

  // FAVOURITES
  Future<void> saveFavouriteIds(Set<String> ids) async {
    final box = Hive.box<String>(_favouritesBox);
    await box.put(_favouriteIdsKey, jsonEncode(ids.toList()));
  }

  Set<String> getFavouriteIds() {
    final box = Hive.box<String>(_favouritesBox);
    final encoded = box.get(_favouriteIdsKey);
    if (encoded == null) return {};
    return (jsonDecode(encoded) as List<dynamic>).cast<String>().toSet();
  }

  Future<void> clearFavouriteIds() async {
    await Hive.box<String>(_favouritesBox).delete(_favouriteIdsKey);
  }

  // Wipes all cached medication data. Next getAllMedications() call
  // starts cold, next fetch pulls fresh from Supabase.
  Future<void> clearAll() async {
    _cachedMedications = null;
    await Future.wait([
      Hive.box<String>(_medicationsBox).clear(),
      Hive.box<String>(_recentSearchesBox).clear(),
      Hive.box<String>(_favouritesBox).clear(),
    ]);
  }
}