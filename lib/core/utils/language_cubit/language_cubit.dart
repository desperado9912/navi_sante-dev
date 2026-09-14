import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'language_state.dart';

export 'language_state.dart';
export 'app_translations.dart';

/// App-wide LanguageCubit managing English and French localization states.
///
/// Automatically persists language selection to Hive, updates GetX locale,
/// and notifies the entire widget tree when the language changes.
class LanguageCubit extends Cubit<LanguageState> {
  static const String _boxName = 'language_settings';
  static const String _keyLangCode = 'app_language_code';

  /// In-memory cache of the active language code for synchronous static lookups.
  static String currentLanguageCode = 'en';

  /// Initializes Hive storage and loads the saved language preference.
  static Future<void> init() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final savedCode = box.get(_keyLangCode);
      if (savedCode != null && savedCode.isNotEmpty) {
        currentLanguageCode = savedCode;
      }
    } catch (e) {
      debugPrint('[LanguageCubit] Init failed (non-fatal): $e');
    }
  }

  LanguageCubit() : super(_getInitialState()) {
    currentLanguageCode = state.code;
  }

  static LanguageState _getInitialState() {
    if (Hive.isBoxOpen(_boxName)) {
      final box = Hive.box<String>(_boxName);
      final savedCode = box.get(_keyLangCode) ?? currentLanguageCode;
      return savedCode == 'fr'
          ? const LanguageState(AppLanguage.fr)
          : const LanguageState(AppLanguage.en);
    }
    return currentLanguageCode == 'fr'
        ? const LanguageState(AppLanguage.fr)
        : const LanguageState(AppLanguage.en);
  }

  /// Sets active language to English.
  Future<void> setEnglish() async {
    currentLanguageCode = 'en';
    emit(const LanguageState(AppLanguage.en));
    await _persist('en');
    _syncGetLocale(const Locale('en', 'US'));
  }

  /// Sets active language to French.
  Future<void> setFrench() async {
    currentLanguageCode = 'fr';
    emit(const LanguageState(AppLanguage.fr));
    await _persist('fr');
    _syncGetLocale(const Locale('fr', 'FR'));
  }

  /// Sets language by enum.
  Future<void> setLanguage(AppLanguage lang) async {
    if (lang == AppLanguage.fr) {
      await setFrench();
    } else {
      await setEnglish();
    }
  }

  /// Sets language by string code ('en' or 'fr').
  Future<void> setLanguageByCode(String code) async {
    if (code.toLowerCase().startsWith('fr')) {
      await setFrench();
    } else {
      await setEnglish();
    }
  }

  /// Toggles between English and French.
  Future<void> toggle() async {
    state.isEnglish ? await setFrench() : await setEnglish();
  }

  Future<void> _persist(String code) async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box<String>(_boxName);
        await box.put(_keyLangCode, code);
      }
    } catch (e) {
      debugPrint('[LanguageCubit] Persist failed: $e');
    }
  }

  void _syncGetLocale(Locale locale) {
    try {
      if (Get.locale != locale) {
        Get.updateLocale(locale);
      }
    } catch (_) {}
  }
}
