import 'package:flutter/foundation.dart';
import 'pharmacy_model.dart';
import 'medication_local.dart';
import 'medication_remote.dart';

// Single entry point for all medication data consumed by PharmacyBloc.
// Bloc never imports MedicationLocal or MedicationRemote directly — same
// rule as FacilityRepository.
//
// DISK I/O SAFETY — read this before touching _fetchFreshMedications().
// A prior version of this feature (and an earlier version of this file)
// let two different call sites — the normal screen-load path and the
// "search arrived with nothing cached" fallback — each independently
// call the network. Under rapid typing or a slow connection, that let
// multiple real Supabase requests fire concurrently, which is exactly
// what exhausted the project's disk I/O budget on a single device.
//
// Every network fetch in this class now funnels through
// _fetchFreshMedications(), which guarantees:
//   1. Single-flight — if a fetch is already in progress, every caller
//      (whether from a normal load or a search fallback) awaits the
//      SAME Future. Never more than one real request in flight.
//   2. Cooldown — a failure is not retried for _fetchFailureCooldown.
//      Repeated search attempts while offline fail fast locally instead
//      of hammering the network on every keystroke.
class MedicationRepository {
  final MedicationLocal _local;
  final MedicationRemote _remote;

  MedicationRepository({
    required MedicationLocal local,
    required MedicationRemote remote,
  }) : _local = local,
       _remote = remote;

  Future<List<MedicationModel>>? _inFlightFetch;
  DateTime? _lastFetchFailureAt;
  static const Duration _fetchFailureCooldown = Duration(seconds: 10);

  /// The ONLY place in this class allowed to call
  /// `_remote.getAllMedications()`. Every other method that needs fresh
  /// data calls this instead of the remote directly.
  Future<List<MedicationModel>> _fetchFreshMedications() {
    final Future<List<MedicationModel>>? inFlight = _inFlightFetch;
    if (inFlight != null) {
      debugPrint('[Pharmacy] Fetch already in flight — sharing it, no new request.');
      return inFlight;
    }

    final DateTime? lastFailure = _lastFetchFailureAt;
    if (lastFailure != null &&
        DateTime.now().difference(lastFailure) < _fetchFailureCooldown) {
      debugPrint('[Pharmacy] Skipping fetch — cooldown active after a recent failure.');
      return Future.error(
        StateError('Medication fetch is on cooldown after a recent failure.'),
      );
    }

    debugPrint('[Pharmacy] Fetching medications from Supabase.');
    final Future<List<MedicationModel>> fetch = _remote
        .getAllMedications()
        .then((fresh) async {
          await _local.saveAllMedications(fresh);
          _lastFetchFailureAt = null;
          return fresh;
        })
        .catchError((Object error, StackTrace stackTrace) {
          _lastFetchFailureAt = DateTime.now();
          Error.throwWithStackTrace(error, stackTrace);
        });

    _inFlightFetch = fetch.whenComplete(() => _inFlightFetch = null);
    return _inFlightFetch!;
  }

  /// Cache-then-network: yields cached data first if present (instant),
  /// then always also fetches fresh so edits/additions/removals in
  /// Supabase are picked up — same shape as
  /// FacilityRepository.getAllFacilities(). No time-based staleness
  /// bookkeeping, per your call to keep this simple.
  Stream<List<MedicationModel>> getAllMedications() async* {
    final cached = _local.getAllMedications();
    if (cached.isNotEmpty) yield cached;

    try {
      yield await _fetchFreshMedications();
    } catch (error) {
      if (cached.isEmpty) rethrow;
      // Cache was already served — swallow the network error.
    }
  }

  /// One-shot fetch used only when a search arrives with nothing in
  /// memory/cache yet (the normal load hasn't completed or failed
  /// silently). Routed through the exact same guarded fetch above, so if
  /// a normal load is already in flight, this simply awaits that call
  /// instead of starting a second one.
  Future<List<MedicationModel>> fetchMedicationsDirect() =>
      _fetchFreshMedications();

  // QUICK FILTER CONDITIONS — tiny, rarely-changing list. Cached in Hive
  // so screens that reopen don't need a network call. A background fetch
  // still updates the cache when possible.
  Future<List<String>> getQuickFilterConditions() async {
    final cached = _local.getQuickFilters();

    try {
      final fresh = await _remote.getQuickFilterConditions();
      await _local.saveQuickFilters(fresh);
      return fresh;
    } catch (_) {
      // Network failed — return whatever we have cached (may be empty on
      // very first launch, which is fine — chips just won't show).
      return cached;
    }
  }

  // RECENT SEARCHES — local only, per-search (not per-view), capped at 5.
  Future<void> addRecentSearch(String term) => _local.addRecentSearch(term);
  List<String> getRecentSearches() => _local.getRecentSearches();
  Future<void> clearRecentSearches() => _local.clearRecentSearches();

  // FAVOURITES — mirrors FacilityRepository's bookmark methods exactly.
  Future<Set<String>> getFavouriteIds() async {
    try {
      final ids = await _remote.getUserFavourites();
      await _local.saveFavouriteIds(ids);
      return ids;
    } catch (_) {
      return _local.getFavouriteIds();
    }
  }

  Future<void> addFavourite(String medicationId) async {
    await _remote.addFavourite(medicationId);
    final ids = _local.getFavouriteIds()..add(medicationId);
    await _local.saveFavouriteIds(ids);
  }

  Future<void> removeFavourite(String medicationId) async {
    await _remote.removeFavourite(medicationId);
    final ids = _local.getFavouriteIds()..remove(medicationId);
    await _local.saveFavouriteIds(ids);
  }

  Future<void> clearFavouriteIds() => _local.clearFavouriteIds();
}