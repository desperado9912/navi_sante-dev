import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

/// Configuration constants for the OpenStreetMap (Carto Light style).
class MapConfig {
  static const String cartoLightUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];
  static const String userAgentPackageName = 'com.navisante.app';

  static const Map<String, String> tileHeaders = {
    'User-Agent': 'NaviSante App (com.navisante.app)',
    'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
  };

  // Zoom parameters
  static const double initialZoom = 17.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;
  static const double zoomStep = 1.0;

  // Prevenet location pulse pin from misplacing location.
  // Fires new user position only after 10 metres.
  static const int trackingDistanceFilter = 10; //metres

  // Fires new user position only after 1 seconds.
  static const int trackingTimeFilter = 1; //seconds

  // Fallback Coordinates (Yaoundé, Cameroon)
  static final LatLng yaoundeLatLng = LatLng(3.8480, 11.5021);
}

/// Abstract representation of location retrieval results.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  final LatLng position;
  const LocationSuccess(this.position);
}

class LocationPermissionDenied extends LocationResult {
  final String message;
  const LocationPermissionDenied(this.message);
}

class LocationFailure extends LocationResult {
  final String message;
  final bool isNetworkError;
  const LocationFailure(this.message, {this.isNetworkError = false});
}

/// A service to cleanly handle permissions and GPS coordinates fetching.
class MapService {
  // Requests permission and fetches the current device position.
  Future<LocationResult> getCurrentLocation({
    bool requestIfNeeded = true,
  }) async {
    try {
      // 1. Check if location services are enabled on the device.
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFailure(
          'Location services are disabled for this device.',
        );
      }

      // 2. Check and request permission if needed
      PermissionStatus status = await Permission.locationWhenInUse.status;

      if (status.isDenied && requestIfNeeded) {
        status = await Permission.locationWhenInUse.request();
      }

      if (status.isPermanentlyDenied) {
        return const LocationPermissionDenied(
          'Location permission denied. Please enable it in device settings.',
        );
      }

      if (!status.isGranted && !status.isLimited) {
        return const LocationPermissionDenied(
          'Location permission limited. Please enable full access in device settings.',
        );
      }

      // 3. Fetch current location
      // Setting a reasonable timeout to handle situations where GPS is slow or blocked.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationSuccess(LatLng(position.latitude, position.longitude));
    } on TimeoutException {
      return const LocationFailure(
        'GPS signal acquisition timed out. Please try again.',
      );
    } catch (e) {
      // Return a general error message
      return LocationFailure('Failed to fetch location: ${e.toString()}');
    }
  }

  // Continuous live tracking stream
  /// getPositionStream() returns a continuous stream via
  /// Geolocator.getPositionStream(). The cubit subscribes to it in initMap()
  /// and silently updates userLocation without re-centering the camera.
  Stream<LocationResult> getPositionStream() async* {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        yield const LocationFailure('Location services are disabled.');
        return;
      }

      final PermissionStatus status = await Permission.locationWhenInUse.status;
      if (!status.isGranted && !status.isLimited) {
        yield const LocationPermissionDenied(
          'Location tracking permission not granted.',
        );
        return;
      }

      final LocationSettings settings;

      // Web
      if (kIsWeb) {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: MapConfig.trackingDistanceFilter,
        );

        // Android
      } else if (Platform.isAndroid) {
        settings = AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: MapConfig.trackingDistanceFilter,
              // Minimum interval between updates — prevents battery drain
              intervalDuration: const Duration(seconds: 1),
            );

        // iOS
      } else {
        settings = AppleSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: MapConfig.trackingDistanceFilter,
              activityType: ActivityType.fitness,
              // Don't let iOS auto-pause tracking when the user is still
              pauseLocationUpdatesAutomatically: false,
            );
      }

      await for (final Position position in Geolocator.getPositionStream(
        locationSettings: settings,
      )) {
        yield LocationSuccess(LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      yield LocationFailure('Location tracking error: ${e.toString()}');
    }
  }
}
