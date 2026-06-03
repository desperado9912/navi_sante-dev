import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../maps/map_service.dart';

/// Base state representing the map's current configuration and context.
abstract class MapState extends Equatable {
  final LatLng center;
  final double zoom;
  final LatLng? userLocation;

  /// A flag indicating whether the widget should smoothly animate the camera to [center] and [zoom].
  final bool animateToState;

  /// A temporary signal used to trigger a one-off snackbar/error notification.
  final String? errorSignal;

  // New features handles
  // final List<HealthFacility> facilities;
  // final HealthFacility? selectedFacility;

  const MapState({
    required this.center,
    required this.zoom,
    this.userLocation,
    this.animateToState = false,
    this.errorSignal,
    // this.facilities = const [],
    // this.selectedFacility,
  });

  @override
  List<Object?> get props => [
    center,
    zoom,
    userLocation,
    animateToState,
    errorSignal,
    // facilities,
    // selectedFacility,
  ];
}

/// Initial state while checking permissions or fetching first GPS coordinate.
class MapLoadingState extends MapState {
  const MapLoadingState({
    required super.center,
    required super.zoom,
    super.userLocation,
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
    // super.facilities,
    // super.selectedFacility,
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
    // super.facilities,
    // super.selectedFacility,
  });

  @override
  List<Object?> get props => [...super.props, errorMessage, isNetworkError];
}

/// Manages the state of the home map, including coordinates, zoom level, and tracking.
class MapCubit extends Cubit<MapState> {
  final MapService _mapService;
  // bool _isCameraMoving = false;
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
  /// If it fails or is denied, it falls back to Yaoundé and shows a snackbar.
  Future<void> initMap() async {
    emit(MapLoadingState(center: state.center, zoom: state.zoom));
    await locateUser(requestPermission: true, isInit: true);
    _startLocationStream();
  }

  /// Attempts to fetch the user's location and animate the map to center on them.
  Future<void> locateUser({
    bool requestPermission = true,
    bool isInit = false,
  }) async {
    // If not initializing, show loading indicators or just trigger fetch
    if (!isInit) {
      emit(
        MapLoadingState(
          center: state.center,
          zoom: state.zoom,
          userLocation: state.userLocation,
        ),
      );
    }
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
          ),
        );

      case LocationPermissionDenied(:final message):
        emit(
          MapErrorState(
            center: MapConfig.yaoundeLatLng,
            zoom: MapConfig.initialZoom,
            userLocation: null,
            errorMessage: message,
            errorSignal: message,
            animateToState: !isInit,
          ),
        );

      case LocationFailure(:final message, :final isNetworkError):
        emit(
          MapErrorState(
            center: MapConfig.yaoundeLatLng,
            zoom: MapConfig.initialZoom,
            userLocation: null,
            errorMessage: message,
            isNetworkError: isNetworkError,
            errorSignal: message,
            animateToState: !isInit,
          ),
        );
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
    if (isClosed) return;
    if (result is! LocationSuccess) return; // Silently skip stream errors

    final MapState current = state;

    if (current is MapLocatedState) {
      emit(
        MapLocatedState(
          center: current.center, // ← preserve camera position
          zoom: current.zoom,
          userLocation: result.position, // ← only the pin moves
          animateToState: false,
        ),
      );
    } else if (current is MapErrorState || current is MapLoadingState) {
      emit(
        MapLocatedState(
          center: result.position,
          zoom: MapConfig.initialZoom,
          userLocation: result.position,
          animateToState: true,
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
        ),
      );
    } else {
      emit(
        MapLocatedState(
          center: newCenter,
          zoom: newZoom,
          userLocation: current.userLocation,
          animateToState: false,
        ),
      );
    }
  }

  /// Clears the error signal after it has been consumed by the UI.
  void clearErrorSignal() {
    final current = state;
    if (current is MapErrorState) {
      emit(
        MapErrorState(
          center: current.center,
          zoom: current.zoom,
          errorMessage: current.errorMessage,
          isNetworkError: current.isNetworkError,
          userLocation: current.userLocation,
          animateToState: false,
          errorSignal: null,
        ),
      );
    } else if (current is MapLocatedState) {
      emit(
        MapLocatedState(
          center: current.center,
          zoom: current.zoom,
          userLocation: current.userLocation,
          animateToState: false,
          errorSignal: null,
        ),
      );
    }
  }

  /// Cleanup
  @override
  Future<void> close() async {
    await _locationStreamSub?.cancel();
    return super.close();
  }
}
