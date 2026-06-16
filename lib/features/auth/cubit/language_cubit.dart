import 'package:flutter_bloc/flutter_bloc.dart';
part 'language_state.dart';

// Login page langauge cubin for language switch.
// TODO: DELETE A CREATE APP WIDE LANGUAGE CUBIT FOR ALL FEATURES.
class LanguageCubit extends Cubit<LanguageState> {
  LanguageCubit() : super(const LanguageState(AppLanguage.en));

  void setEnglish() => emit(const LanguageState(AppLanguage.en));
  void setFrench() => emit(const LanguageState(AppLanguage.fr));

  void toggle() {
    state.isEnglish ? setFrench() : setEnglish();
  }
}
