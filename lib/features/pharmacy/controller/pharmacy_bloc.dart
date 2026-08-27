import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/medication_repository.dart';
import 'medication_search.dart';
import 'pharmacy_model.dart';

// EVENTS
abstract class PharmacyEvent {}

/// Loads the medication catalog (cache-then-network) plus quick-filter
/// conditions and recent searches. Safe to dispatch repeatedly — see
/// the `droppable()` transformer below; a load already in progress
/// simply absorbs duplicate dispatches instead of starting a second one.
class LoadMedications extends PharmacyEvent {}

class SearchMedications extends PharmacyEvent {
  final String query;
  SearchMedications(this.query);
}

class ClearMedicationSearch extends PharmacyEvent {}

class ClearRecentSearches extends PharmacyEvent {}

class LoadFavourites extends PharmacyEvent {}

class ToggleFavourite extends PharmacyEvent {
  final String medicationId;
  ToggleFavourite(this.medicationId);
}

class ClearFavourites extends PharmacyEvent {}

/// Internal — fired by ToggleFavourite's debounce timer, never
/// dispatched directly by the UI.
class _CommitFavourite extends PharmacyEvent {
  final String medicationId;
  final bool shouldBeFavourited;
  _CommitFavourite(this.medicationId, this.shouldBeFavourited);
}

// STATE
enum MedicationStatus { initial, loading, loaded, error }

const Object _unset = Object();

class PharmacyState extends Equatable {
  final List<MedicationModel> medications;
  final MedicationStatus medicationsStatus;
  final String? errorMessage;

  final List<String> commonQuickFilters;

  /// '' when there's no active search — the default-medications view.
  final String activeQuery;
  final List<MedicationModel> searchResults;

  /// Capped at 5, most-recent-first. Per-search, not per-view.
  final List<String> recentSearches;

  final Set<String> favouriteIds;
  final MedicationStatus favouritesStatus;

  // ── Pre-computed derived fields ─────────────────────────────────────
  // Computed once at construction time — never re-derived during builds.

  /// Up to 5 medications flagged via default_rank, in rank order — shown
  /// when there's no active search.
  final List<MedicationModel> defaultMedications;

  /// Recent searches first (most personally relevant), then common
  /// quick-filter conditions not already present among recents.
  final List<String> mergedQuickFilters;

  const PharmacyState._({
    required this.medications,
    required this.medicationsStatus,
    this.errorMessage,
    required this.commonQuickFilters,
    required this.activeQuery,
    required this.searchResults,
    required this.recentSearches,
    required this.favouriteIds,
    required this.favouritesStatus,
    required this.defaultMedications,
    required this.mergedQuickFilters,
  });

  /// The only public constructor. Computes [defaultMedications] and
  /// [mergedQuickFilters] once so every subsequent property access is a
  /// simple field read — no sort/filter/set-ops on every widget build.
  factory PharmacyState({
    List<MedicationModel> medications = const [],
    MedicationStatus medicationsStatus = MedicationStatus.initial,
    String? errorMessage,
    List<String> commonQuickFilters = const [],
    String activeQuery = '',
    List<MedicationModel> searchResults = const [],
    List<String> recentSearches = const [],
    Set<String> favouriteIds = const {},
    MedicationStatus favouritesStatus = MedicationStatus.initial,
  }) {
    return PharmacyState._(
      medications: medications,
      medicationsStatus: medicationsStatus,
      errorMessage: errorMessage,
      commonQuickFilters: commonQuickFilters,
      activeQuery: activeQuery,
      searchResults: searchResults,
      recentSearches: recentSearches,
      favouriteIds: favouriteIds,
      favouritesStatus: favouritesStatus,
      defaultMedications: _computeDefaultMedications(medications),
      mergedQuickFilters: _computeMergedQuickFilters(
        recentSearches,
        commonQuickFilters,
      ),
    );
  }

  bool get isMedicationsLoading => medicationsStatus == MedicationStatus.loading;
  bool get hasMedications => medications.isNotEmpty;
  bool get isSearching => activeQuery.isNotEmpty;
  bool get hasNoResults =>
      isSearching &&
      searchResults.isEmpty &&
      medicationsStatus == MedicationStatus.loaded;

  bool isFavourited(String medicationId) => favouriteIds.contains(medicationId);

  PharmacyState copyWith({
    List<MedicationModel>? medications,
    MedicationStatus? medicationsStatus,
    Object? errorMessage = _unset,
    List<String>? commonQuickFilters,
    String? activeQuery,
    List<MedicationModel>? searchResults,
    List<String>? recentSearches,
    Set<String>? favouriteIds,
    MedicationStatus? favouritesStatus,
  }) {
    return PharmacyState(
      medications: medications ?? this.medications,
      medicationsStatus: medicationsStatus ?? this.medicationsStatus,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      commonQuickFilters: commonQuickFilters ?? this.commonQuickFilters,
      activeQuery: activeQuery ?? this.activeQuery,
      searchResults: searchResults ?? this.searchResults,
      recentSearches: recentSearches ?? this.recentSearches,
      favouriteIds: favouriteIds ?? this.favouriteIds,
      favouritesStatus: favouritesStatus ?? this.favouritesStatus,
    );
  }

  // ── Static helpers for pre-computation ──────────────────────────────

  static List<MedicationModel> _computeDefaultMedications(
    List<MedicationModel> medications,
  ) {
    final ranked = medications.where((m) => m.defaultRank != null).toList()
      ..sort((a, b) => a.defaultRank!.compareTo(b.defaultRank!));
    return ranked.take(5).toList();
  }

  static List<String> _computeMergedQuickFilters(
    List<String> recentSearches,
    List<String> commonQuickFilters,
  ) {
    final Set<String> seen = recentSearches
        .map((s) => s.toLowerCase())
        .toSet();
    final List<String> merged = [...recentSearches];
    for (final String common in commonQuickFilters) {
      if (seen.add(common.toLowerCase())) merged.add(common);
    }
    return merged;
  }

  @override
  List<Object?> get props => [
    medications,
    medicationsStatus,
    errorMessage,
    commonQuickFilters,
    activeQuery,
    searchResults,
    recentSearches,
    favouriteIds,
    favouritesStatus,
  ];
}

// BLOC
class PharmacyBloc extends Bloc<PharmacyEvent, PharmacyState> {
  final MedicationRepository _repository;
  static const MedicationSearchEngine _searchEngine = MedicationSearchEngine();

  final Map<String, Timer?> _favouriteTimers = {};

  Timer? _medicationsRetryTimer;
  int _medicationsRetryAttempt = 0;
  static const List<Duration> _medicationsRetryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  PharmacyBloc({required MedicationRepository repository})
    : _repository = repository,
      super(PharmacyState()) {
    // droppable(): if LoadMedications/LoadFavourites is already running,
    // a duplicate dispatch (e.g. both the Pharmacy screen and the
    // Favourites screen mounting around the same time) is simply
    // ignored rather than starting a second network round trip.
    on<LoadMedications>(_onLoadMedications, transformer: droppable());
    on<LoadFavourites>(_onLoadFavourites, transformer: droppable());

    // restartable(): only the latest keystroke's search matters — an
    // older, slower search in flight is abandoned so its (possibly
    // stale) result can never land after a newer one.
    on<SearchMedications>(_onSearchMedications, transformer: restartable());

    on<ClearMedicationSearch>(_onClearMedicationSearch);
    on<ClearRecentSearches>(_onClearRecentSearches);

    on<ToggleFavourite>(_onToggleFavourite);
    // sequential(): favourite commits (the actual Supabase write) run
    // strictly one at a time — same pattern as facility bookmarks.
    on<_CommitFavourite>(_onCommitFavourite, transformer: sequential());
    on<ClearFavourites>(_onClearFavourites);
  }

  // LOAD MEDICATIONS — cache-then-network stream + quick filters + recents
  Future<void> _onLoadMedications(
    LoadMedications event,
    Emitter<PharmacyState> emit,
  ) async {
    if (state.medications.isEmpty) {
      emit(state.copyWith(medicationsStatus: MedicationStatus.loading));
    }

    await emit.forEach<List<MedicationModel>>(
      _repository.getAllMedications(),
      onData: (meds) => state.copyWith(
        medications: meds,
        medicationsStatus: MedicationStatus.loaded,
        errorMessage: null,
      ),
      onError: (error, stackTrace) => state.copyWith(
        medicationsStatus: MedicationStatus.error,
        errorMessage: state.hasMedications
            ? null
            : 'Unable to load medications. Check your connection.',
      ),
    );

    // Local-only, cheap — safe to do on every load.
    emit(state.copyWith(recentSearches: _repository.getRecentSearches()));

    // Non-critical network call — chips just won't show on failure.
    try {
      final quickFilters = await _repository.getQuickFilterConditions();
      emit(state.copyWith(commonQuickFilters: quickFilters));
    } catch (_) {
      // Swallow — the medication list itself already loaded (or failed
      // and is being retried below); quick filters are a nice-to-have.
    }

    if (state.medicationsStatus == MedicationStatus.loaded) {
      _medicationsRetryTimer?.cancel();
      _medicationsRetryAttempt = 0;
    } else if (state.medicationsStatus == MedicationStatus.error &&
        state.medications.isEmpty) {
      _scheduleMedicationsRetry();
    }
  }

  /// Silent background retry — only when there's truly nothing to show
  /// (first launch, no cache, no network). No UI involved. Composes with
  /// the repository's own cooldown: an early retry that lands inside the
  /// cooldown window fails fast locally with no real network call.
  void _scheduleMedicationsRetry() {
    if (_medicationsRetryAttempt >= _medicationsRetryDelays.length) return;

    final Duration delay = _medicationsRetryDelays[_medicationsRetryAttempt];
    _medicationsRetryAttempt++;

    _medicationsRetryTimer?.cancel();
    _medicationsRetryTimer = Timer(delay, () {
      if (isClosed) return;
      add(LoadMedications());
    });
  }

  // SEARCH — always filters state.medications (already in memory, zero
  // network). Only falls back to a guarded direct fetch if that pool is
  // genuinely empty.
  Future<void> _onSearchMedications(
    SearchMedications event,
    Emitter<PharmacyState> emit,
  ) async {
    final String query = event.query.trim();
    if (query.isEmpty) {
      emit(state.copyWith(activeQuery: '', searchResults: const []));
      return;
    }

    List<MedicationModel> pool = state.medications;
    if (pool.isEmpty) {
      // Nothing loaded yet (or the load failed silently) — fetch once,
      // directly. Routed through MedicationRepository's single-flight +
      // cooldown guard, so this can never duplicate a load already in
      // flight, and a recent failure fails fast instead of retrying the
      // network on every keystroke.
      emit(state.copyWith(medicationsStatus: MedicationStatus.loading));
      try {
        pool = await _repository.fetchMedicationsDirect();
        emit(
          state.copyWith(
            medications: pool,
            medicationsStatus: MedicationStatus.loaded,
            errorMessage: null,
          ),
        );
      } catch (_) {
        emit(
          state.copyWith(
            medicationsStatus: MedicationStatus.error,
            errorMessage: 'Unable to load medications. Check your connection.',
            activeQuery: query,
            searchResults: const [],
          ),
        );
        return;
      }
    }

    final MedicationSearchResult result = _searchEngine.search(pool, query);
    emit(state.copyWith(activeQuery: query, searchResults: result.matches));

    if (result.matches.isNotEmpty && result.chipTerm != null) {
      await _repository.addRecentSearch(result.chipTerm!);
      emit(state.copyWith(recentSearches: _repository.getRecentSearches()));
    }
  }

  Future<void> _onClearMedicationSearch(
    ClearMedicationSearch event,
    Emitter<PharmacyState> emit,
  ) async {
    emit(state.copyWith(activeQuery: '', searchResults: const []));
  }

  Future<void> _onClearRecentSearches(
    ClearRecentSearches event,
    Emitter<PharmacyState> emit,
  ) async {
    await _repository.clearRecentSearches();
    emit(state.copyWith(recentSearches: const []));
  }

  // FAVOURITES
  Future<void> _onLoadFavourites(
    LoadFavourites event,
    Emitter<PharmacyState> emit,
  ) async {
    emit(state.copyWith(favouritesStatus: MedicationStatus.loading));
    final ids = await _repository.getFavouriteIds();
    emit(
      state.copyWith(
        favouriteIds: ids,
        favouritesStatus: MedicationStatus.loaded,
      ),
    );
  }

  /// Optimistic toggle: flips the heart instantly, then debounces the
  /// actual network write so rapid taps only commit the final state —
  /// same event-driven "icon switches before the network confirms" flow
  /// as facility bookmarks. Reverts + surfaces an error if the eventual
  /// commit fails.
  void _onToggleFavourite(ToggleFavourite event, Emitter<PharmacyState> emit) {
    final String id = event.medicationId;
    final bool willBeFavourited = !state.isFavourited(id);

    final Set<String> optimistic = Set<String>.from(state.favouriteIds);
    if (willBeFavourited) {
      optimistic.add(id);
    } else {
      optimistic.remove(id);
    }
    emit(state.copyWith(favouriteIds: optimistic));

    _favouriteTimers[id]?.cancel();
    _favouriteTimers[id] = Timer(const Duration(milliseconds: 500), () {
      if (isClosed) return;
      add(_CommitFavourite(id, willBeFavourited));
    });
  }

  Future<void> _onCommitFavourite(
    _CommitFavourite event,
    Emitter<PharmacyState> emit,
  ) async {
    _favouriteTimers.remove(event.medicationId);
    try {
      if (event.shouldBeFavourited) {
        await _repository.addFavourite(event.medicationId);
      } else {
        await _repository.removeFavourite(event.medicationId);
      }
    } catch (_) {
      final Set<String> reverted = Set<String>.from(state.favouriteIds);
      if (event.shouldBeFavourited) {
        reverted.remove(event.medicationId);
      } else {
        reverted.add(event.medicationId);
      }
      emit(
        state.copyWith(
          favouriteIds: reverted,
          errorMessage: 'Could not update favourites. Please try again.',
        ),
      );
    }
  }

  Future<void> _onClearFavourites(
    ClearFavourites event,
    Emitter<PharmacyState> emit,
  ) async {
    for (final timer in _favouriteTimers.values) {
      timer?.cancel();
    }
    _favouriteTimers.clear();
    await _repository.clearFavouriteIds();
    emit(
      state.copyWith(
        favouriteIds: const {},
        favouritesStatus: MedicationStatus.initial,
      ),
    );
  }

  @override
  Future<void> close() {
    for (final timer in _favouriteTimers.values) {
      timer?.cancel();
    }
    _favouriteTimers.clear();
    _medicationsRetryTimer?.cancel();
    return super.close();
  }
}