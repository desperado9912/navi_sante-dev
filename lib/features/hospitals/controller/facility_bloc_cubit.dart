import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/facility_model.dart';
import '../data/facility_repository.dart';

// Manages facility data (what to do, what to show).
// This is the controller that house all functions which dictate business logic
// regarding facilities data.
// Controls all facility data state for both the map screen and hospitals screen.
// Uses a COMPOSITE STATE pattern — one state object with multiple independent
// fields and a copyWith method — rather than many separate state classes.

// Satus enum: Used for each independent loading concern in FacilityState.
// initial  → never loaded (first app launch, no cache)
// loading  → network/hive call in progress
// loaded   → data available
// error    → last call failed
enum FacilityStatus { initial, loading, loaded, error }

abstract class FacilityEvent {}

class LoadFacilities extends FacilityEvent {}

class LoadHighlights extends FacilityEvent {
  final double userLat;
  final double userLng;

  LoadHighlights({required this.userLat, required this.userLng});
}

class SearchFacilities extends FacilityEvent {
  final String query;
  final String? typeFilter; // ('hospital', 'clinic', 'pharmacy', null)
  final String? cityFilter; // city name | null
  final double minRating; // 0.0 = no minimum

  SearchFacilities({
    required this.query,
    this.typeFilter,
    this.cityFilter,
    this.minRating = 0.0,
  });
}

class ClearSearch extends FacilityEvent {}

// Fired when user taps a map pin, carousel card, grid card, or search result.
class LoadFacilityDetail extends FacilityEvent {
  final String facilityId;

  LoadFacilityDetail(this.facilityId);
}

class FacilityState {
  // Full list — all facilities loaded once and kept for the lifetime of the BLoC.
  final List<FacilityModel> facilities;

  // Top N closest to user — derived from facilities list, no network call.
  final List<FacilityModel> highlights;

  // Current search results — separate from facilities list.
  // Empty when not in search mode.
  final List<FacilityModel> searchResults;

  // Currently viewed facility detail — used by bottom sheet + detail screen.
  final FacilityDetailModel? currentDetail;

  // Independent status trackers for each concern.
  final FacilityStatus facilitiesStatus;
  final FacilityStatus searchStatus;
  final FacilityStatus detailStatus;

  // The query text that produced the current searchResults.
  final String? activeQuery;

  // Last error message — surfaces to UI for snackbars or error widgets.
  final String? errorMessage;

  const FacilityState({
    this.facilities = const [],
    this.highlights = const [],
    this.searchResults = const [],
    this.currentDetail,
    this.facilitiesStatus = FacilityStatus.initial,
    this.searchStatus = FacilityStatus.initial,
    this.detailStatus = FacilityStatus.initial,
    this.activeQuery,
    this.errorMessage,
  });

  // copyWith — Sentinel pattern for nullable currentDetail.

  static const Object _sentinel = Object();

  FacilityState copyWith({
    List<FacilityModel>? facilities,
    List<FacilityModel>? highlights,
    List<FacilityModel>? searchResults,
    Object? currentDetail = _sentinel,
    FacilityStatus? facilitiesStatus,
    FacilityStatus? searchStatus,
    FacilityStatus? detailStatus,
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
      facilitiesStatus: facilitiesStatus ?? this.facilitiesStatus,
      searchStatus: searchStatus ?? this.searchStatus,
      detailStatus: detailStatus ?? this.detailStatus,
      activeQuery: activeQuery ?? this.activeQuery,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  // Convenience getters — used in UI without boilerplate
  bool get hasFacilities => facilities.isNotEmpty;
  bool get hasHighlights => highlights.isNotEmpty;
  bool get hasResults => searchResults.isNotEmpty;
  bool get isSearchActive => activeQuery != null && activeQuery!.isNotEmpty;

  bool get isFacilitiesLoading => facilitiesStatus == FacilityStatus.loading;
  bool get isSearchLoading => searchStatus == FacilityStatus.loading;
  bool get isDetailLoading => detailStatus == FacilityStatus.loading;
}

// BLOC handles business logic.

class FacilityBloc extends Bloc<FacilityEvent, FacilityState> {
  final FacilityRepository _repository;

  FacilityBloc({required FacilityRepository repository})
    : _repository = repository,
      super(const FacilityState()) {
    on<LoadFacilities>(_onLoadFacilities);
    on<LoadHighlights>(_onLoadHighlights);
    on<SearchFacilities>(_onSearchFacilities);
    on<ClearSearch>(_onClearSearch);
    on<LoadFacilityDetail>(_onLoadFacilityDetail);
  }

  // LOAD FACILITIES — cache-then-network stream
  //
  // Emission 1 (Hive cache):
  //   Arrives immediately. Map renders all pins. No spinner shown.
  //   If Hive is empty on first launch, loading state IS shown briefly.
  //
  // Emission 2 (Supabase network):
  //   Arrives after RPC completes. Map silently updates with fresh data.
  //   User sees no disruption — the update is seamless.

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
            ? null // Cache was served — swallow error silently
            : 'Unable to load facilities. Check your connection.',
      ),
    );
  }

  // LOAD HIGHLIGHTS — synchronous, zero network.
  // getHighlights() reads Hive and sorts in Dart — no async needed.
  //
  // Emits immediately → no loading state → carousel updates instantly
  // whenever the user's location changes.
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

    if (query.isEmpty) {
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
  // On a Hive hit, the future resolves almost instantly (no network).
  // On a miss, fetches from Supabase and caches before returning.
  //
  // A null result means the facility_id doesn't exist in the database.
  // This should never happen in practice (tapping a real pin/card), but
  // the error state handles it gracefully.
  Future<void> _onLoadFacilityDetail(
    LoadFacilityDetail event,
    Emitter<FacilityState> emit,
  ) async {
    emit(
      state.copyWith(detailStatus: FacilityStatus.loading, currentDetail: null),
    );

    try {
      // The repository checks Hive first.
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

      emit(
        state.copyWith(
          currentDetail: detail,
          detailStatus: FacilityStatus.loaded,
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
}
