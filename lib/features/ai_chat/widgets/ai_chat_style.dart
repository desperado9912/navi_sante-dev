import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/language_cubit/auth_language_cubit.dart';

const kNaviTeal = Color(0xFF2A7D8F);
const kNaviChatBg = Color(0xFFF8F9F8);

bool isFrench(BuildContext context) {
  try {
    return !context.read<LanguageCubit>().state.isEnglish;
  } catch (_) {
    return false;
  }
}

String t(BuildContext context, String en, String fr) =>
    isFrench(context) ? fr : en;
