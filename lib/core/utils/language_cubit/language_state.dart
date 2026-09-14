import 'package:flutter/material.dart';

enum AppLanguage { en, fr }

class LanguageState {
  final AppLanguage language;
  const LanguageState(this.language);

  bool get isEnglish => language == AppLanguage.en;
  bool get isFrench => language == AppLanguage.fr;
  String get code => language == AppLanguage.en ? 'en' : 'fr';
  String get upperCode => language == AppLanguage.en ? 'EN' : 'FR';
  String get flag => language == AppLanguage.en ? '🇬🇧' : '🇫🇷';
  String get displayName => language == AppLanguage.en ? 'English' : 'Français';

  Locale get locale => language == AppLanguage.en
      ? const Locale('en', 'US')
      : const Locale('fr', 'FR');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageState &&
          runtimeType == other.runtimeType &&
          language == other.language;

  @override
  int get hashCode => language.hashCode;
}
