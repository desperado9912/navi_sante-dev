import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'facility_model.dart';
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

class LoadFacilities extends FacilityEvent {}

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

// Bookmarks
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
  final List<FacilityModel> savedFacilities;

  // Independent status trackers for each concern.
  final FacilityStatus facilitiesStatus;
  final FacilityStatus searchStatus;
  final FacilityStatus detailStatus;
  final FacilityStatus bookmarkStatus;

  // The query text that produced the current searchResults.
  final String? activeQuery;

  // Last error message — surfaced to the UI for snackbars or error widgets.
  final String? errorMessage;

  const FacilityState({
    this.facilities = const [],
    this.highlights = const [],
    this.searchResults = const [],
    this.currentDetail,
    this.recentlyViewedIds = const [],
    this.bookmarkedIds = const {},
    this.savedFacilities = const [],
    this.facilitiesStatus = FacilityStatus.initial,
    this.searchStatus = FacilityStatus.initial,
    this.detailStatus = FacilityStatus.initial,
    this.bookmarkStatus = FacilityStatus.initial,
    this.activeQuery,
    this.errorMessage,
  });

  // Sentinel pattern for nullable fields in copyWith.
  static const Object _sentinel = Object();

  FacilityState copyWith({
    List<FacilityModel>? facilities,
    List<FacilityModel>? highlights,
    List<FacilityModel>? searchResults,
    Object? currentDetail = _sentinel,
    List<String>? recentlyViewedIds,
    Set<String>? bookmarkedIds,
    List<FacilityModel>? savedFacilities,
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
      savedFacilities: savedFacilities ?? this.savedFacilities,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

class FacilityBloc extends Bloc<FacilityEvent, FacilityState> {
  final FacilityRepository _repository;

  FacilityBloc({required FacilityRepository repository})
    : _repository = repository,
      super(const FacilityState()) {
    // Facility List
    on<LoadFacilities>(_onLoadFacilities);
    on<LoadHighlights>(_onLoadHighlights);
    // Search
    on<SearchFacilities>(_onSearchFacilities);
    on<ClearSearch>(_onClearSearch);
    // Detail
    on<LoadFacilityDetail>(_onLoadFacilityDetail);
    // Recently Viewed
    on<LoadRecentlyViewed>(_onLoadRecentlyViewed);
    on<AddRecentlyViewed>(_onAddRecentlyViewed);
    on<ClearRecentlyViewed>(_onClearRecentlyViewed);
    // Bookmarks
    on<LoadBookmarks>(_onLoadBookmarks);
    on<RefreshBookmarks>(_onRefreshBookmarks);
    on<ToggleBookmark>(_onToggleBookmark);
    on<ClearBookmarks>(_onClearBookmarks);
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
      _repository.getAllFacilities(),
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
    final hasActiveFilters = event.typeFilter != null ||
                             event.cityFilter != null ||
                             event.serviceFilter != null ||
                             event.priceRangeFilter != null ||
                             event.minRating > 0;

    if (query.isEmpty && !hasActiveFilters) {
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
  /// Loads bookmarks on auth (Hndles in auth gate).
  Future<void> _onLoadBookmarks(
    LoadBookmarks event,
    Emitter<FacilityState> emit,
  ) async {
    // Prevent redundant network calls if already loaded.
    if (state.bookmarkedIds.isNotEmpty || state.savedFacilities.isNotEmpty) {
      return;
    }

    emit(state.copyWith(bookmarkStatus: FacilityStatus.loading));

    // Exponential backoff retry (up to 3 attempts)
    int retries = 0;
    while (retries < 3) {
      try {
        final bookmarks = await _repository.getUserBookmarks();
        final ids = bookmarks.map((b) => b.facilityId).toSet();
        emit(
          state.copyWith(
            bookmarkedIds: ids,
            savedFacilities: bookmarks,
            bookmarkStatus: FacilityStatus.loaded,
          ),
        );
        return;
      } catch (_) {
        retries++;
        await Future.delayed(Duration(seconds: retries * 3));
      }
    }

    // All retries exhausted — fail silently, restore previous state.
    emit(state.copyWith(bookmarkStatus: FacilityStatus.error));
  }

  /// Force-refresh bookmarks (e.g. from pull-to-refresh).
  Future<void> _onRefreshBookmarks(
    RefreshBookmarks event,
    Emitter<FacilityState> emit,
  ) async {
    emit(state.copyWith(bookmarkStatus: FacilityStatus.loading));

    try {
      final bookmarks = await _repository.getUserBookmarks();
      final ids = bookmarks.map((b) => b.facilityId).toSet();
      emit(
        state.copyWith(
          bookmarkedIds: ids,
          savedFacilities: bookmarks,
          bookmarkStatus: FacilityStatus.loaded,
        ),
      );
    } catch (_) {
      // Restore previous bookmark data; just stop loading.
      emit(state.copyWith(bookmarkStatus: FacilityStatus.error));
    }
  }

  /// Bookmark toggle: update the UI immediately, before sync to Supabase.
  /// If the network call fails, the state is automatically reverted.
  Future<void> _onToggleBookmark(
    ToggleBookmark event,
    Emitter<FacilityState> emit,
  ) async {
    final facilityId = event.facilityId;
    final wasBookmarked = state.bookmarkedIds.contains(facilityId);

    // Optimistic update
    final optimisticIds = Set<String>.from(state.bookmarkedIds);
    final optimisticFacilities = List<FacilityModel>.from(
      state.savedFacilities,
    );

    if (wasBookmarked) {
      optimisticIds.remove(facilityId);
      optimisticFacilities.removeWhere((f) => f.facilityId == facilityId);
    } else {
      optimisticIds.add(facilityId);
      final model = _repository.getFacilitySync(facilityId);
      if (model != null) optimisticFacilities.insert(0, model);
    }

    emit(
      state.copyWith(
        bookmarkedIds: optimisticIds,
        savedFacilities: optimisticFacilities,
      ),
    );

    // Network sync
    try {
      if (wasBookmarked) {
        await _repository.removeBookmark(facilityId);
      } else {
        await _repository.addBookmark(facilityId);
      }
    } catch (_) {
      // auto-revert on failure
      final revertedIds = Set<String>.from(state.bookmarkedIds);
      final revertedFacilities = List<FacilityModel>.from(
        state.savedFacilities,
      );

      if (wasBookmarked) {
        revertedIds.add(facilityId);
        final model = _repository.getFacilitySync(facilityId);
        if (model != null) revertedFacilities.insert(0, model);
      } else {
        revertedIds.remove(facilityId);
        revertedFacilities.removeWhere((f) => f.facilityId == facilityId);
      }

      emit(
        state.copyWith(
          bookmarkedIds: revertedIds,
          savedFacilities: revertedFacilities,
        ),
      );
    }
  }

  /// Wipes all bookmark state — called on sign-out.
  Future<void> _onClearBookmarks(
    ClearBookmarks event,
    Emitter<FacilityState> emit,
  ) async {
    emit(
      state.copyWith(
        bookmarkedIds: const {},
        savedFacilities: const [],
        bookmarkStatus: FacilityStatus.initial,
      ),
    );
  }
}
