import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../profile/controllers/navigationApp_settings.dart';

// Url launcher file to configure launching 'get directions' in native map app.
// Launches the user's preferred maps app with a pre-set destination for navigation.
// All methods are static — call MapLauncher.openDirections(...) directly.

class MapLauncher {
  MapLauncher._();

  /// [facilityName] is appended to the URI so the destination pin
  /// shows the hospital name instead of just coordinates.
  static Future<void> openDirections({
    required double latitude,
    required double longitude,
    required String facilityName,
  }) async {
    final String preferredApp = NavigationSettings.getPreferredApp();

    // 1. Try the native deep-link URI (opens installed app directly)
    final Uri nativeUri = _buildNativeUri(
      latitude: latitude,
      longitude: longitude,
      facilityName: facilityName,
      app: preferredApp,
    );

    bool launched = false;
    if (await canLaunchUrl(nativeUri)) {
      launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    }

    // 2. If native URI failed (app not installed), fall back to the web URL
    if (!launched) {
      final Uri webUri = _buildWebFallbackUri(
        latitude: latitude,
        longitude: longitude,
        facilityName: facilityName,
        app: preferredApp,
      );
      launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    if (!launched) {
      throw const MapLaunchException('No maps application found on this device.');
    }
  }

  // Link URIs (opens selected app)
  static Uri _buildNativeUri({
    required double latitude,
    required double longitude,
    required String facilityName,
    required String app,
  }) {
    switch (app) {
      case 'waze':
        return Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes');

      case 'google':
        if (!kIsWeb && Platform.isIOS) {
          return Uri.parse(
            'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
          );
        }
        // Android: intent-based URI for Google Maps navigation
        return Uri.parse('google.navigation:q=$latitude,$longitude');

      case 'apple':
        // Apple Maps deep link works on iOS; on Android it won't resolve,
        // so the web fallback will handle it.
        return Uri(
          scheme: 'maps',
          queryParameters: {
            'daddr': '$latitude,$longitude',
            'q': facilityName,
          },
        );

      default:
        // Should not happen, but default to platform-appropriate URI
        if (!kIsWeb && Platform.isIOS) {
          return Uri(
            scheme: 'maps',
            queryParameters: {
              'daddr': '$latitude,$longitude',
              'q': facilityName,
            },
          );
        }
        return Uri.parse('google.navigation:q=$latitude,$longitude');
    }
  }

  // ── Web fallback URIs (opens in browser if app is not installed) ──────────
  static Uri _buildWebFallbackUri({
    required double latitude,
    required double longitude,
    required String facilityName,
    required String app,
  }) {
    switch (app) {
      case 'waze':
        return Uri.parse(
          'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
        );

      case 'google':
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$latitude,$longitude',
        );

      case 'apple':
        return Uri.parse(
          'https://maps.apple.com/?daddr=$latitude,$longitude'
          '&q=${Uri.encodeComponent(facilityName)}',
        );

      default:
        // Generic fallback — Google Maps web
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$latitude,$longitude',
        );
    }
  }

  /// Generates a sharing URL using the user's preferred navigation app web link.
  static String generateShareUrl({
    required double latitude,
    required double longitude,
    required String facilityName,
  }) {
    final String preferredApp = NavigationSettings.getPreferredApp();
    return _buildWebFallbackUri(
      latitude: latitude,
      longitude: longitude,
      facilityName: facilityName,
      app: preferredApp,
    ).toString();
  }
}

// EXCEPTION
/// Throws [MapLaunchException] if the maps app cannot be opened.
/// The UI catches MapLaunchException and shows a SnackBar message.
class MapLaunchException implements Exception {
  final String message;
  const MapLaunchException(this.message);

  @override
  String toString() => 'MapLaunchException: $message';
}
