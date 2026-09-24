import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../data/facility_model.dart';
import '../data/facility_repository.dart';

/// The Controller / Business Logic Layer for all facility operations.

// Uses a COMPOSITE STATE pattern — one state object with multiple independent
// fields and a copyWith method — rather than many separate state classes.
/// Handles:
//   Loading / streaming all facilities data (cache-then-network)
//   Streaming closest facilities (synchronous, zero network)
//   Search queries with optional filters
//   Facility details (cache-first)
//   Recently viewed history (persisted in Hive)
//   Bookmarks toggle UI updates with auto-rollback on + retry on load failure.
//
/// NEVER imports FacilityLocal or FacilityRemote directly. All network calls go through [FacilityRepository].

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────────────────────────────────────
abstract class FacilityEvent {}

class LoadFacilities extends FacilityEvent {
  final bool force;
  LoadFacilities({this.force = false});
}

class _FacilitiesUpdated extends FacilityEvent {
  final List<FacilityModel> facilities;
  _FacilitiesUpdated(this.facilities);
}

class LoadHighlights extends FacilityEvent {
  final double userLat;
  final double userLng;
  LoadHighlights({required this.userLat, required this.userLng});
}

// Search
class SearchFacilities extends FacilityEvent {
  final String query;
  final String? typeFilter;
  final String? cityFilter;
  final String? serviceFilter;
  final String? priceRangeFilter;
  final double minRating;
  SearchFacilities({
    required this.query,
    this.typeFilter,
    this.cityFilter,
    this.serviceFilter,
    this.priceRangeFilter,
    this.minRating = 0.0,
  });
}

class ClearSearch extends FacilityEvent {}

/// Fired when the user taps a map pin, carousel card, grid card, or search result.
class LoadFacilityDetail extends FacilityEvent {
  final String facilityId;
  LoadFacilityDetail(this.facilityId);
}

// Recently Viewed
class LoadRecentlyViewed extends FacilityEvent {}

class AddRecentlyViewed extends FacilityEvent {
  final String facilityId;
  AddRecentlyViewed(this.facilityId);
}

class ClearRecentlyViewed extends FacilityEvent {}

/// Load the user's saved bookmarks.
class LoadBookmarks extends FacilityEvent {}

/// Force-refresh bookmarks (e.g. pull-to-refresh on the Saved Facilities screen).
class RefreshBookmarks extends FacilityEvent {}

/// Optimistically toggle a bookmark and sync to Supabase; auto-reverts on error.
class ToggleBookmark extends FacilityEvent {
  final String facilityId;
  ToggleBookmark(this.facilityId);
}

/// Clear all bookmark state (called on sign-out).
class ClearBookmarks extends FacilityEvent {}

/// Internal event — dispatched by a debounce timer after [ToggleBookmark].
/// Performs the actual Supabase write and silently reverts on failure.
/// Not intended for external use.
class _CommitBookmark extends FacilityEvent {
  final String facilityId;
  final bool shouldBeBookmarked;
  _CommitBookmark(this.facilityId, {required this.shouldBeBookmarked});
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

enum FacilityStatus { initial, loading, loaded, error }

class FacilityState {
  // Full list — all facilities loaded once and kept for the lifetime of the BLoC.
  final List<FacilityModel> facilities;

  // Top N closest to user — derived from facilities list, no network call.
  final List<FacilityModel> highlights;

  // Current search results — separate from the facilities list.
  final List<FacilityModel> searchResults;

  // Currently viewed facility detail — used by bottom sheet + detail screen.
  final FacilityDetailModel? currentDetail;

  // Recently viewed facility IDs (max 5) — persisted in Hive.
  final List<String> recentlyViewedIds;

  // Bookmark state — IDs in a Set for O(1) look-ups; full models for the list screen.
  final Set<String> bookmarkedIds;

  // Independent status trackers for each concern.
  final FacilityStatus facilitiesStatus;
  final FacilityStatus searchStatus;
  final FacilityStatus detailStatus;
  final FacilityStatus bookmarkStatus;

  // The query text that produced the current searchResults.
  final String? activeQuery;

  // Last error message — surfaced to the UI for snackbars or error widgets.
  final String? errorMessage;

  // ── Pre-computed derived fields ──────────────────────────────────────
  // Computed once at state construction time — zero work during widget builds.

  /// Non-pharmacy facilities sorted by rating (top 10) for the Hospitals browse grid.
  final List<FacilityModel> hospitalBrowseList;

  /// O(1) lookup map keyed by facilityId — used by recent history, detail loading, etc.
  final Map<String, FacilityModel> _facilityById;

  FacilityState({
    this.facilities = const [],
    this.highlights = const [],
    this.searchResults = const [],
    this.currentDetail,
    this.recentlyViewedIds = const [],
    this.bookmarkedIds = const {},
    this.facilitiesStatus = FacilityStatus.initial,
    this.searchStatus = FacilityStatus.initial,
    this.detailStatus = FacilityStatus.initial,
    this.bookmarkStatus = FacilityStatus.initial,
    this.activeQuery,
    this.errorMessage,
  })  : hospitalBrowseList = _computeHospitalBrowseList(facilities),
        _facilityById = { for (final f in facilities) f.facilityId: f };

  static List<FacilityModel> _computeHospitalBrowseList(List<FacilityModel> facilities) {
    if (facilities.isEmpty) return const [];
    final filtered = facilities.where((f) => f.type != FacilityType.pharmacy).toList();
    filtered.sort((a, b) => b.rating.compareTo(a.rating));
    return filtered.length > 10 ? filtered.sublist(0, 10) : filtered;
  }

  /// Returns the facility with [facilityId], or null if not found. O(1).
  FacilityModel? facilityById(String facilityId) => _facilityById[facilityId];

  // Sentinel pattern for nullable fields in copyWith.
  static const Object _sentinel = Object();

  FacilityState copyWith({
    List<FacilityModel>? facilities,
    List<FacilityModel>? highlights,
    List<FacilityModel>? searchResults,
    Object? currentDetail = _sentinel,
    List<String>? recentlyViewedIds,
    Set<String>? bookmarkedIds,
    FacilityStatus? facilitiesStatus,
    FacilityStatus? searchStatus,
    FacilityStatus? detailStatus,
    FacilityStatus? bookmarkStatus,
    String? activeQuery,
    Object? errorMessage = _sentinel,
  }) {
    return FacilityState(
      facilities: facilities ?? this.facilities,
      highlights: highlights ?? this.highlights,
      searchResults: searchResults ?? this.searchResults,
      currentDetail: identical(currentDetail, _sentinel)
          ? this.currentDetail
          : currentDetail as FacilityDetailModel?,
      recentlyViewedIds: recentlyViewedIds ?? this.recentlyViewedIds,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      facilitiesStatus: facilitiesStatus ?? this.facilitiesStatus,
      searchStatus: searchStatus ?? this.searchStatus,
      detailStatus: detailStatus ?? this.detailStatus,
      bookmarkStatus: bookmarkStatus ?? this.bookmarkStatus,
      activeQuery: activeQuery ?? this.activeQuery,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  // ── Convenience getters — used in UI without boilerplate ──
  bool get hasFacilities => facilities.isNotEmpty;
  bool get hasHighlights => highlights.isNotEmpty;
  bool get hasResults => searchResults.isNotEmpty;
  bool get isSearchActive => searchStatus != FacilityStatus.initial;

  bool get isFacilitiesLoading => facilitiesStatus == FacilityStatus.loading;
  bool get isSearchLoading => searchStatus == FacilityStatus.loading;
  bool get isDetailLoading => detailStatus == FacilityStatus.loading;
  bool get isBookmarkLoading => bookmarkStatus == FacilityStatus.loading;

  bool isBookmarked(String facilityId) => bookmarkedIds.contains(facilityId);

  // get saved facilities
  List<FacilityModel> get savedFacilities =>
      facilities.where((f) => bookmarkedIds.contains(f.facilityId)).toList();

  @override
  String toString() => 'FacilityState(facilities: ${facilities.length}, status: $facilitiesStatus)';
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

class FacilityBloc extends Bloc<FacilityEvent, FacilityState> {
  final FacilityRepository _repository;

  /// Per-facility debounce timers for bookmark writes.
  /// Rapid taps cancel/restart the timer so only the final desired state
  /// is committed to Supabase.
  final Map<String, Timer?> _bookmarkTimers = {};
  StreamSubscription<List<FacilityModel>>? _facilitiesRepoSubscription;
  double? _lastUserLat;
  double? _lastUserLng;

  FacilityBloc({required FacilityRepository repository})
    : _repository = repository,
      super( FacilityState()) {
    // Facility List
    on<LoadFacilities>(_onLoadFacilities, transformer: droppable());
    on<_FacilitiesUpdated>(_onFacilitiesUpdated, transformer: restartable());
    on<LoadHighlights>(_onLoadHighlights);

    // Listen to live database changes / search additions from repository
    _facilitiesRepoSubscription = _repository.facilitiesStream.listen((updatedList) {
      add(_FacilitiesUpdated(updatedList));
    });
    // Search — restartable so a newer query never lets a stale emit win.
    on<SearchFacilities>(_onSearchFacilities, transformer: restartable());
    on<ClearSearch>(_onClearSearch);
    // Detail — latest selected facility wins; skip no-op in the handler.
    on<LoadFacilityDetail>(_onLoadFacilityDetail, transformer: restartable());
    // Recently Viewed
    on<LoadRecentlyViewed>(_onLoadRecentlyViewed);
    on<AddRecentlyViewed>(_onAddRecentlyViewed);
    on<ClearRecentlyViewed>(_onClearRecentlyViewed);
    // Bookmarks
    on<LoadBookmarks>(_onLoadBookmarks);
    on<RefreshBookmarks>(_onRefreshBookmarks, transformer: droppable());
    on<ToggleBookmark>(_onToggleBookmark);
    on<_CommitBookmark>(_onCommitBookmark, transformer: sequential());
    on<ClearBookmarks>(_onClearBookmarks);
  }

  void _onFacilitiesUpdated(
    _FacilitiesUpdated event,
    Emitter<FacilityState> emit,
  ) {
    List<FacilityModel>? updatedHighlights;
    if (_lastUserLat != null && _lastUserLng != null) {
      updatedHighlights = _repository.getHighlights(
        userLat: _lastUserLat!,
        userLng: _lastUserLng!,
      );
    }
    emit(state.copyWith(
      facilities: event.facilities,
      highlights: updatedHighlights ?? state.highlights,
      facilitiesStatus: FacilityStatus.loaded,
    ));
  }

  // LOAD FACILITIES — cache-then-network stream
  Future<void> _onLoadFacilities(
    LoadFacilities event,
    Emitter<FacilityState> emit,
  ) async {
    if (state.facilities.isEmpty) {
      emit(state.copyWith(facilitiesStatus: FacilityStatus.loading));
    }

    await emit.forEach<List<FacilityModel>>(
      _repository.getAllFacilities(force: event.force),
      onData: (facilities) => state.copyWith(
        facilities: facilities,
        facilitiesStatus: FacilityStatus.loaded,
        errorMessage: null,
      ),
      onError: (error, stackTrace) => state.copyWith(
        facilitiesStatus: FacilityStatus.error,
        errorMessage: state.hasFacilities
            ? null
            : 'Unable to load facilities. Check your connection.',
      ),
    );
  }

  // LOAD HIGHLIGHTS (Carousel) — synchronous, zero network
  Future<void> _onLoadHighlights(
    LoadHighlights event,
    Emitter<FacilityState> emit,
  ) async {
    _lastUserLat = event.userLat;
    _lastUserLng = event.userLng;
    final highlights = _repository.getHighlights(
      userLat: event.userLat,
      userLng: event.userLng,
    );
    emit(state.copyWith(highlights: highlights));
  }

  // SEARCH FACILITIES
  Future<void> _onSearchFacilities(
    SearchFacilities event,
    Emitter<FacilityState> emit,
  ) async {
    final query = event.query.trim();
    final hasActiveFilters =
        event.typeFilter != null ||
        event.cityFilter != null ||
        event.serviceFilter != null ||
        event.priceRangeFilter != null ||
        event.minRating > 0;

    if (query.isEmpty && !hasActiveFilters) {
      _repository.cancelPendingSearch();
      emit(
        state.copyWith(
          searchResults: [],
          searchStatus: FacilityStatus.initial,
          activeQuery: null,
          errorMessage: null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(searchStatus: FacilityStatus.loading, activeQuery: query),
    );

    try {
      final results = await _repository.searchFacilities(
        query: query,
        typeFilter: event.typeFilter,
        cityFilter: event.cityFilter,
        serviceFilter: event.serviceFilter,
        priceRangeFilter: event.priceRangeFilter,
        minRating: event.minRating,
      );
      emit(
        state.copyWith(
          searchResults: results,
          searchStatus: FacilityStatus.loaded,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          searchStatus: FacilityStatus.error,
          errorMessage: 'Search failed. Please try again.',
        ),
      );
    }
  }

  // CLEAR SEARCH
  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<FacilityState> emit,
  ) async {
    _repository.cancelPendingSearch();
    emit(
      state.copyWith(
        searchResults: [],
        searchStatus: FacilityStatus.initial,
        activeQuery: null,
        errorMessage: null,
      ),
    );
  }

  // LOAD FACILITY DETAIL — cache-first
  Future<void> _onLoadFacilityDetail(
    LoadFacilityDetail event,
    Emitter<FacilityState> emit,
  ) async {
    if (state.currentDetail?.facilityId == event.facilityId &&
        state.detailStatus == FacilityStatus.loaded) {
      await _repository.saveRecentlyViewed(event.facilityId);
      return;
    }

    emit(
      state.copyWith(detailStatus: FacilityStatus.loading, currentDetail: null),
    );

    try {
      final detail = await _repository.getFacilityDetail(event.facilityId);

      if (detail == null) {
        emit(
          state.copyWith(
            detailStatus: FacilityStatus.error,
            errorMessage: 'Facility details not found.',
          ),
        );
        return;
      }

      // Automatically save to recently viewed.
      await _repository.saveRecentlyViewed(event.facilityId);
      final updatedRecents = [
        event.facilityId,
        ...state.recentlyViewedIds.where((id) => id != event.facilityId),
      ].take(5).toList();

      emit(
        state.copyWith(
          currentDetail: detail,
          detailStatus: FacilityStatus.loaded,
          recentlyViewedIds: updatedRecents,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          detailStatus: FacilityStatus.error,
          errorMessage: 'Failed to load facility details.',
        ),
      );
    }
  }

  // RECENTLY VIEWED
  void _onLoadRecentlyViewed(
    LoadRecentlyViewed event,
    Emitter<FacilityState> emit,
  ) {
    final ids = _repository.getRecentlyViewed();
    emit(state.copyWith(recentlyViewedIds: ids.take(5).toList()));
  }

  Future<void> _onAddRecentlyViewed(
    AddRecentlyViewed event,
    Emitter<FacilityState> emit,
  ) async {
    final updated = [
      event.facilityId,
      ...state.recentlyViewedIds.where((id) => id != event.facilityId),
    ].take(5).toList();
    emit(state.copyWith(recentlyViewedIds: updated));
    await _repository.saveRecentlyViewed(event.facilityId);
  }

  Future<void> _onClearRecentlyViewed(
    ClearRecentlyViewed event,
    Emitter<FacilityState> emit,
  ) async {
    emit(state.copyWith(recentlyViewedIds: const []));
    await _repository.clearRecentlyViewed();
  }

  // BOOKMARKS
  /// Loads bookmarks on auth (Handles in auth gate).
  Future<void> _onLoadBookmarks(
    LoadBookmarks event,
    Emitter<FacilityState> emit,
  ) async {
    if (state.bookmarkStatus == FacilityStatus.loaded) return;
    await _fetchAndEmitBookmarks(emit);
  }

  // Manual force pull to refresh on Saved facilities screen.
  Future<void> _onRefreshBookmarks(
    RefreshBookmarks event,
    Emitter<FacilityState> emit,
  ) async {
    await _fetchAndEmitBookmarks(emit);
  }

  // Internal helper: fetch once, apply retry logic, update state.
  // Shared helper for both LoadBookmarks and RefreshBookmarks.
  Future<void> _fetchAndEmitBookmarks(Emitter<FacilityState> emit) async {
    emit(state.copyWith(bookmarkStatus: FacilityStatus.loading));
    try {
      final ids = await _repository.getBookmarkedIds();
      emit(
        state.copyWith(
          bookmarkedIds: ids,
          bookmarkStatus: FacilityStatus.loaded,
        ),
      );
    } catch (_) {
      emit(state.copyWith(bookmarkStatus: FacilityStatus.error));
    }
  }

  // ── Bookmark toggle — optimistic emit + debounced commit ──────────────
  // Instant icon update on tap. The actual Supabase write is deferred by
  // 300ms via a per-facility timer. Rapid taps cancel/restart the timer so
  // only the *final* desired state gets committed — no flip-flop flicker.
  Future<void> _onToggleBookmark(
    ToggleBookmark event,
    Emitter<FacilityState> emit,
  ) async {
    final facilityId = event.facilityId;
    final wasBookmarked = state.bookmarkedIds.contains(facilityId);
    final shouldBeBookmarked = !wasBookmarked;

    // 1. Optimistic update — icon flips instantly.
    final optimisticIds = Set<String>.from(state.bookmarkedIds);
    if (shouldBeBookmarked) {
      optimisticIds.add(facilityId);
    } else {
      optimisticIds.remove(facilityId);
    }
    emit(state.copyWith(bookmarkedIds: optimisticIds));

    // 2. Cancel any pending commit for this facility (debounce).
    _bookmarkTimers[facilityId]?.cancel();

    // 3. Schedule the actual Supabase write after a 300ms quiet window.
    //    If the user taps again within 300ms, this timer is replaced.
    _bookmarkTimers[facilityId] = Timer(
      const Duration(milliseconds: 300),
      () => add(_CommitBookmark(
        facilityId,
        shouldBeBookmarked: shouldBeBookmarked,
      )),
    );
  }

  // ── Commit bookmark — actual network write with silent revert ─────────
  // Dispatched by the debounce timer. Writes the desired state to Supabase.
  // If the current local state has already diverged (user toggled again
  // after this commit was scheduled), the write is skipped — the newer
  // commit will handle it. On network failure, silently reverts the icon.
  Future<void> _onCommitBookmark(
    _CommitBookmark event,
    Emitter<FacilityState> emit,
  ) async {
    final facilityId = event.facilityId;
    final shouldBeBookmarked = event.shouldBeBookmarked;

    // Clean up the timer reference.
    _bookmarkTimers.remove(facilityId);

    // Guard: if the user toggled again since this commit was scheduled,
    // the current state won't match the intended write — skip it.
    final currentlyBookmarked = state.bookmarkedIds.contains(facilityId);
    if (currentlyBookmarked != shouldBeBookmarked) return;

    try {
      if (shouldBeBookmarked) {
        await _repository.addBookmark(facilityId);
      } else {
        await _repository.removeBookmark(facilityId);
      }
    } catch (_) {
      // Silent revert — no snackbar, no error message.
      // Only reverts this specific facility; other concurrent bookmarks
      // are unaffected.
      final revertedIds = Set<String>.from(state.bookmarkedIds);
      if (shouldBeBookmarked) {
        revertedIds.remove(facilityId);
      } else {
        revertedIds.add(facilityId);
      }
      emit(state.copyWith(bookmarkedIds: revertedIds));
    }
  }

  // Clears all bookmark state — called on sign-out.
  Future<void> _onClearBookmarks(
    ClearBookmarks event,
    Emitter<FacilityState> emit,
  ) async {
    // Cancel all pending bookmark commits before clearing.
    for (final timer in _bookmarkTimers.values) {
      timer?.cancel();
    }
    _bookmarkTimers.clear();
    _repository.cancelPendingSearch();
    await _repository.clearBookmarkIds();
    emit(
      state.copyWith(
        bookmarkedIds: const {},
        bookmarkStatus: FacilityStatus.initial,
      ),
    );
  }

  @override
  Future<void> close() {
    _facilitiesRepoSubscription?.cancel();
    // Cancel all pending bookmark debounce timers on bloc disposal.
    for (final timer in _bookmarkTimers.values) {
      timer?.cancel();
    }
    _bookmarkTimers.clear();
    _repository.cancelPendingSearch();
    return super.close();
  }
}
