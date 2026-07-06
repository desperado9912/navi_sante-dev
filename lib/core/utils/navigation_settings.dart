import 'dart:io' show Platform;
import 'package:hive_flutter/hive_flutter.dart';

class NavigationSettings {
  static const String _boxName = 'app_settings';
  static const String _navAppKey = 'preferred_navigation_app';

  /// Initializes the settings box. Should be called during app startup if needed, 
  /// but Hive.openBox can also be awaited on first access.
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  /// Platform-aware default: Apple Maps on iOS, Google Maps on Android.
  static String get _platformDefault =>
      Platform.isIOS ? 'apple' : 'google';

  /// Returns the stored navigation app code.
  /// Falls back to the platform default (apple on iOS, google on Android).
  /// Valid values: 'google', 'apple', 'waze'
  static String getPreferredApp() {
    if (!Hive.isBoxOpen(_boxName)) return _platformDefault;
    final box = Hive.box(_boxName);
    final stored = box.get(_navAppKey) as String?;
    // If nothing stored yet, or legacy 'native' value, return platform default
    if (stored == null || stored == 'native') return _platformDefault;
    return stored;
  }

  /// Saves the user's preferred navigation app code.
  static Future<void> setPreferredApp(String appCode) async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    final box = Hive.box(_boxName);
    await box.put(_navAppKey, appCode);
  }
}
