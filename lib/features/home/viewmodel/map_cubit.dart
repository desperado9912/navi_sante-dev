import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../map/map_service.dart';

/// Base state representing the map's current configuration and context.
/// Handles map functions and states.
abstract class MapState extends Equatable {
  final LatLng center;
  final double zoom;
  final LatLng? userLocation;

  /// A flag indicating whether the widget should smoothly animate the camera to [center] and [zoom].
  final bool animateToState;

  /// A temporary signal used to trigger a one-off snackbar/error notification.
  final String? errorSignal;

  final MapInteractionState interactionState;

  const MapState({
    required this.center,
    required this.zoom,
    this.userLocation,
    this.animateToState = false,
    this.errorSignal,
    this.interactionState = const MapIdle(),
  });

  @override
  List<Object?> get props => [
    center,
    zoom,
    userLocation,
    animateToState,
    errorSignal,
    interactionState,
  ];

  MapState copyWith({
    LatLng? center,
    double? zoom,
    LatLng? userLocation,
    bool? animateToState,
    Object? errorSignal = _unset,
    MapInteractionState? interactionState,
  }) {
    final String? resolvedErrorSignal = identical(errorSignal, _unset)
        ? this.errorSignal
        : errorSignal as String?;

    if (this is MapLoadingState) {
      return MapLoadingState(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        userLocation: userLocation ?? this.userLocation,
        interactionState: interactionState ?? this.interactionState,
      );
    } else if (this is MapErrorState) {
      final err = this as MapErrorState;
      return MapErrorState(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        errorMessage: err.errorMessage,
        isNetworkError: err.isNetworkError,
        userLocation: userLocation ?? this.userLocation,
        animateToState: animateToState ?? this.animateToState,
        errorSignal: resolvedErrorSignal,
        interactionState: interactionState ?? this.interactionState,
      );
    } else {
      return MapLocatedState(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        userLocation: userLocation ?? this.userLocation,
        animateToState: animateToState ?? this.animateToState,
        errorSignal: resolvedErrorSignal,
        interactionState: interactionState ?? this.interactionState,
      );
    }
  }
}

const Object _unset = Object();

/// Initial state while checking permissions or fetching first GPS coordinate.
class MapLoadingState extends MapState {
  const MapLoadingState({
    required super.center,
    required super.zoom,
    super.userLocation,
    super.interactionState = const MapIdle(),
  });
}

/// Active state when the map has loaded a position (user location or fallback Yaoundé).
class MapLocatedState extends MapState {
  const MapLocatedState({
    required super.center,
    required super.zoom,
    super.userLocation,
    super.animateToState,
    super.errorSignal,
    super.interactionState = const MapIdle(),
  });
}

/// State representing an error (permission denied, GPS timeout, network failure).
class MapErrorState extends MapState {
  final String errorMessage;
  final bool isNetworkError;

  const MapErrorState({
    required super.center,
    required super.zoom,
    required this.errorMessage,
    this.isNetworkError = false,
    super.userLocation,
    super.animateToState,
    super.errorSignal,
    super.interactionState = const MapIdle(),
  });

  @override
  List<Object?> get props => [...super.props, errorMessage, isNetworkError];
}

abstract class MapInteractionState extends Equatable {
  const MapInteractionState();

  @override
  List<Object?> get props => const [];
}

// Default: all pins visible, carousel showing 5 closest.
class MapIdle extends MapInteractionState {
  const MapIdle();
}

// User tapped pin: pin is scaled up, mini card shown, carousel hidden.
class MapPinSelected extends MapInteractionState {
  final String facilityId; // Which pin is highlighted
  const MapPinSelected(this.facilityId);

  @override
  List<Object?> get props => [facilityId];
}

// Bottom sheet is expanded (came from pin tap or carousel card tap).
class MapDetailSheet extends MapInteractionState {
  final String facilityId;
  const MapDetailSheet(this.facilityId);

  @override
  List<Object?> get props => [facilityId];
}

/// Manages the state of the home map, including coordinates, zoom level, and tracking.
class MapCubit extends Cubit<MapState> {
  final MapService _mapService;
  final LocationAccuracyFilter _accuracyFilter = const LocationAccuracyFilter();
  StreamSubscription<LocationResult>? _locationStreamSub;

  MapCubit({MapService? mapService})
    : _mapService = mapService ?? MapService(),
      super(
        MapLoadingState(
          center: MapConfig.yaoundeLatLng,
          zoom: MapConfig.initialZoom,
        ),
      );

  /// Initializes the map. Attempts to locate the user immediately.
  /// Uses last-known position for instant first render, then refines
  /// with a fresh GPS fix. Fallback to Yaounde on failure or denied access.
  Future<void> initMap() async {
    if (_locationStreamSub != null) return;

    emit(
      MapLoadingState(
        center: state.center,
        zoom: state.zoom,
        userLocation: state.userLocation,
        interactionState: state.interactionState,
      ),
    );

    // Show last-known position instantly while waiting for fresh GPS.
    final LocationResult? lastKnown = await _mapService.getLastKnownLocation();
    if (!isClosed && lastKnown is LocationSuccess) {
      emit(
        MapLocatedState(
          center: lastKnown.position,
          zoom: MapConfig.initialZoom,
          userLocation: lastKnown.position,
          animateToState: false, // No animation on first render
          interactionState: state.interactionState,
        ),
      );
    }

    // Now fetch a fresh, accurate fix (may take a few seconds).
    await locateUser(requestPermission: true, isInit: true);
    _startLocationStream();
  }

  bool _isLocating = false;

  /// Attempts to fetch the user's location and animate the map to center on them.
  ///
  /// When triggered by the locate button (isInit=false), does NOT emit
  /// MapLoadingState so the UI stays interactive. Instead, it instantly
  /// pans to the OS-cached last-known position, then refines with a
  /// fresh GPS fix.
  Future<void> locateUser({
    bool requestPermission = true,
    bool isInit = false,
  }) async {
    // If not initializing and we already know where they are, just pan instantly.
    // This avoids triggering the GPS hardware again and causing freezes/delays.
    if (!isInit && state.userLocation != null) {
      emit(
        MapLocatedState(
          center: state.userLocation!,
          zoom: MapConfig.initialZoom,
          userLocation: state.userLocation,
          animateToState: true,
          interactionState: state.interactionState,
        ),
      );
      return;
    }

    if (_isLocating) return;
    _isLocating = true;
    try {
      // Fetch fresh, accurate GPS fix.
      LocationResult result = await _mapService.getCurrentLocation(
        requestIfNeeded: requestPermission,
      );

      if (isClosed) return;

      switch (result) {
        case LocationSuccess(:final position):
          emit(
            MapLocatedState(
              center: position,
              zoom: MapConfig.initialZoom,
              userLocation: position,
              animateToState: true,
              interactionState: state.interactionState,
            ),
          );

        case LocationPermissionDenied(:final message):
          // If we already showed a last-known position, keep it visible
          // but still signal the permission error.
          final LatLng? currentUserLoc = state.userLocation;
          emit(
            MapErrorState(
              center: currentUserLoc ?? MapConfig.yaoundeLatLng,
              zoom: MapConfig.initialZoom,
              userLocation: currentUserLoc,
              errorMessage: message,
              errorSignal: message,
              animateToState: !isInit && currentUserLoc == null,
              interactionState: state.interactionState,
            ),
          );

        case LocationFailure(:final message, :final isNetworkError):
          // If we already have a position (from last-known or stream),
          // keep showing it — don't wipe the pin on a transient GPS timeout.
          final LatLng? currentUserLoc = state.userLocation;
          if (currentUserLoc != null) {
            // Keep current state, just signal the error transiently.
            emit(
              MapLocatedState(
                center: state.center,
                zoom: state.zoom,
                userLocation: currentUserLoc,
                animateToState: false,
                errorSignal: message,
                interactionState: state.interactionState,
              ),
            );
          } else {
            emit(
              MapErrorState(
                center: MapConfig.yaoundeLatLng,
                zoom: MapConfig.initialZoom,
                userLocation: null,
                errorMessage: message,
                isNetworkError: isNetworkError,
                errorSignal: message,
                animateToState: !isInit,
                interactionState: state.interactionState,
              ),
            );
          }
      }
    } finally {
      _isLocating = false;
    }
  }

  /// Live User Location Stream function
  void _startLocationStream() {
    _locationStreamSub?.cancel();
    _locationStreamSub = _mapService.getPositionStream().listen(
      _onLiveLocationUpdate,
      cancelOnError: false,
    );
  }

  /// Live User Location Stream Listener
  void _onLiveLocationUpdate(LocationResult result) {
    if (isClosed || result is! LocationSuccess) return; // Skip stream errors

    final bool hasExistingFix = state.userLocation != null;
    if (hasExistingFix &&
        !_accuracyFilter.isAcceptable(result.accuracyMeters)) {
      return; // Keep showing the last good fix instead of a noisy one.
    }

    final MapState previous = state;

    if (previous is MapLocatedState) {
      emit(
        MapLocatedState(
          center: previous.center,
          zoom: previous.zoom,
          userLocation: result.position,
          animateToState: false,
          errorSignal: previous.errorSignal,
          interactionState: previous.interactionState,
        ),
      );
    } else {
      emit(
        MapLocatedState(
          center: result.position,
          zoom: MapConfig.initialZoom,
          userLocation: result.position,
          animateToState: true,
          errorSignal: previous.errorSignal,
          interactionState: previous.interactionState,
        ),
      );
    }
  }

  /// Map zoom controlls
  // Increments the current map zoom level with bounds clamping.
  void zoomIn() {
    final double targetZoom = (state.zoom + MapConfig.zoomStep).clamp(
      MapConfig.minZoom,
      MapConfig.maxZoom,
    );
    if (targetZoom != state.zoom) {
      emit(
        MapLocatedState(
          center: state.center,
          zoom: targetZoom,
          userLocation: state.userLocation,
          animateToState: true,
          errorSignal: state.errorSignal,
          interactionState: state.interactionState,
        ),
      );
    }
  }

  // Decrements the current map zoom level with bounds clamping.
  void zoomOut() {
    final double targetZoom = (state.zoom - MapConfig.zoomStep).clamp(
      MapConfig.minZoom,
      MapConfig.maxZoom,
    );
    if (targetZoom != state.zoom) {
      emit(
        MapLocatedState(
          center: state.center,
          zoom: targetZoom,
          userLocation: state.userLocation,
          animateToState: true,
          errorSignal: state.errorSignal,
          interactionState: state.interactionState,
        ),
      );
    }
  }

  /// Updates the internal viewport when user pans/zooms the map manually.
  void updateViewport(LatLng newCenter, double newZoom) {
    final current = state;
    if (current is MapErrorState) {
      emit(
        MapErrorState(
          center: newCenter,
          zoom: newZoom,
          errorMessage: current.errorMessage,
          isNetworkError: current.isNetworkError,
          userLocation: current.userLocation,
          animateToState:
              false, // User is manually dragging, don't trigger animation feedback
          errorSignal: current.errorSignal,
          interactionState: current.interactionState,
        ),
      );
    } else {
      emit(
        MapLocatedState(
          center: newCenter,
          zoom: newZoom,
          userLocation: current.userLocation,
          animateToState: false,
          errorSignal: current.errorSignal,
          interactionState: current.interactionState,
        ),
      );
    }
  }

  /// Clears the error signal after it has been consumed by the UI.
  void clearErrorSignal() {
    emit(state.copyWith(errorSignal: null));
  }

  /// Cleanup
  @override
  Future<void> close() async {
    await _locationStreamSub?.cancel();
    return super.close();
  }

  // Other Interaction map states

  /// User tapped a map pin. Tell FacilityBloc to load the details in widget.
  void selectPin(String facilityId) {
    emit(state.copyWith(interactionState: MapPinSelected(facilityId)));
  }

  /// User tapped the expand button on the mini card.
  void expandSheet(String facilityId) {
    emit(state.copyWith(interactionState: MapDetailSheet(facilityId)));
  }

  /// User tapped the map background, cleared search, or dragged sheet down.
  void returnToIdle() {
    emit(state.copyWith(interactionState: MapIdle()));
  }
}
