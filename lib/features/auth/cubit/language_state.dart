part of 'language_cubit.dart';

enum AppLanguage { en, fr }

class LanguageState {
  final AppLanguage language;
  const LanguageState(this.language);

  bool get isEnglish => language == AppLanguage.en;
  String get code => language == AppLanguage.en ? 'EN' : 'FR';
  String get flag => language == AppLanguage.en ? '🇬🇧' : '🇫🇷';
}
