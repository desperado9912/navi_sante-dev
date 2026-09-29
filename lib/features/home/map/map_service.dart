import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

/// Configuration constants for the OpenStreetMap (Carto Light style).
class MapConfig {
  static String get _apiKey => dotenv.env['CARTO_API_KEY']?.trim() ?? '';

  static String get cartoLightUrl {
    final key = _apiKey;
    if (key.isNotEmpty) {
      return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png?key=$key';
    }
    return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  }

  static String get fallbackUrl {
    final key = _apiKey;
    if (key.isNotEmpty) {
      return 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png?key=$key';
    }
    return 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  }

  static const List<String> subdomains = ['a'];
  static String get tileSubdomain => subdomains.first;
  static const String userAgentPackageName = 'com.navisante.app';

  static const Map<String, String> tileHeaders = {
    'User-Agent': 'NaviSante App (com.navisante.app)',
    'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
  };

  // Zoom parameters
  static const double initialZoom = 16.0;
  static const double minZoom = 5.0;
  static const double maxZoom = 18.0;
  static const double zoomStep = 1.0;

  // Live tracking should not wait for a large distance jump. The Cubit still
  // filters weak-accuracy fixes, while the pulser animates every good update.
  static const int trackingDistanceFilter = 0; // metres
  static const Duration trackingInterval = Duration(milliseconds: 350);

  // Fallback Coordinates (Yaoundé, Cameroon)
  static final LatLng yaoundeLatLng = LatLng(3.8480, 11.5021);
}

/// Abstract representation of location retrieval results.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  final LatLng position;
  final double accuracyMeters;

  const LocationSuccess(this.position, {required this.accuracyMeters});

  factory LocationSuccess.fromPosition(Position position) {
    return LocationSuccess(
      LatLng(position.latitude, position.longitude),
      accuracyMeters: position.accuracy,
    );
  }
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

// Filters location results and drops unreliable locations. Prevents the UI from
// displaying low-confidence readings as the user's exact position.
class LocationAccuracyFilter {
  const LocationAccuracyFilter({this.maxAcceptableAccuracyMeters = 50});
  final double maxAcceptableAccuracyMeters;

  bool isAcceptable(double accuracyMeters) =>
      accuracyMeters <= maxAcceptableAccuracyMeters;
}

/// A service to cleanly handle permissions and GPS coordinates fetching.
class MapService {

  /// Returns the OS-cached last known position instantly (no GPS radio needed).
  /// Returns null if no cached position exists.
  Future<LocationResult?> getLastKnownLocation() async {
    try {
      final Position? position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return LocationSuccess.fromPosition(position);
    } catch (_) {
      return null;
    }
  }

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

      // 3. Fetch current location with high accuracy.
      // 8s timeout is a safety net — the caller should have already shown
      // a last-known position so the user isn't staring at a blank map.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return LocationSuccess.fromPosition(position);
    } on TimeoutException {
      return const LocationFailure(
        'GPS signal acquisition timed out. Please try again.',
      );
    } catch (e) {
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

        // Android — high accuracy is sufficient for a facility finder and
        // avoids the device overload / crash seen with bestForNavigation.
      } else if (Platform.isAndroid) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: MapConfig.trackingDistanceFilter,
          intervalDuration: MapConfig.trackingInterval,
        );

        // iOS
      } else {
        settings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: MapConfig.trackingDistanceFilter,
          activityType: ActivityType.otherNavigation,
          // Don't let iOS auto-pause tracking when the user is still
          pauseLocationUpdatesAutomatically: false,
        );
      }

      await for (final Position position in Geolocator.getPositionStream(
        locationSettings: settings,
      )) {
        yield LocationSuccess.fromPosition(position);
      }
    } catch (e) {
      yield LocationFailure('Location tracking error: ${e.toString()}');
    }
  }
}
