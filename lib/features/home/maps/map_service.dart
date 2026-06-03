import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

/// Configuration constants for the OpenStreetMap (Carto Light style).
class MapConfig {
  static const String cartoLightUrl = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];
  static const String userAgentPackageName = 'com.navisante.app';
  
  static const Map<String, String> tileHeaders = {
    'User-Agent': 'NaviSante App (com.navisante.app)',
    'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
  };

  // Zoom parameters
  static const double initialZoom = 16.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;
  static const double zoomStep = 1.0;

  // Fallback Coordinates (Yaoundé, Cameroon)
  static final LatLng yaoundeLatLng = LatLng(3.8480, 11.5021);
}

/// Enum representing the type of medical facility.
enum FacilityType { hospital, pharmacy, clinic }

// /// Data model representing health facilities.
// class HealthFacility {
//   final String id;
//   final String name;
//   final String description;
//   final LatLng coordinate;
//   final FacilityType type;
//   final String contactNumber;
//   final bool is24Hours;

//   const HealthFacility({
//     required this.id,
//     required this.name,
//     required this.description,
//     required this.coordinate,
//     required this.type,
//     this.contactNumber = '',
//     this.is24Hours = false,
//   });
// }

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
  /// Requests permission and fetches the current device position.
  /// If [requestIfNeeded] is false, it only checks if already granted, and otherwise returns denied.
  Future<LocationResult> getCurrentLocation({bool requestIfNeeded = true}) async {
    try {
      // 1. Check if location services are enabled on the device.
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFailure('Location services are disabled for this device.');
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
          accuracy: LocationAccuracy.high,
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

  // /// Triggers Apple Maps or Google Maps external intent frameworks cleanly based on device OS.
  // Future<void> launchExternalNavigation(LatLng destination, String title) async {
  //   final String lat = destination.latitude.toString();
  //   final String lng = destination.longitude.toString();
    
  //   final Uri appleMapsUri = Uri.parse('maps://?q=${Uri.encodeComponent(title)}&ll=$lat,$lng');
  //   final Uri googleMapsUri = Uri.parse('https://google.com');

  //   try {
  //     if (await canLaunchUrl(appleMapsUri)) {
  //       await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
  //     } else if (await canLaunchUrl(googleMapsUri)) {
  //       await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
  //     } else {
  //       debugPrint('No native application maps clients found.');
  //     }
  //   } catch (e) {
  //     debugPrint('Intent navigation execution error: $e');
  //   }
  // }
}
