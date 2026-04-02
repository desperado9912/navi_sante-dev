import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/language_cubit.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanguageCubit, LanguageState>(
      builder: (context, state) {
        return PopupMenuButton<AppLanguage>(
          onSelected: (lang) {
            if (lang == AppLanguage.en) {
              context.read<LanguageCubit>().setEnglish();
            } else {
              context.read<LanguageCubit>().setFrench();
            }
          },
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: Color(0xFF2A7D8F),
              size: 22,
            ),
          ),
          itemBuilder: (_) => [
            _languageItem(AppLanguage.en, '🇬🇧', 'English', state),
            _languageItem(AppLanguage.fr, '🇫🇷', 'Français', state),
          ],
        );
      },
    );
  }

  PopupMenuItem<AppLanguage> _languageItem(
    AppLanguage lang,
    String flag,
    String label,
    LanguageState state,
  ) {
    final isSelected = state.language == lang;
    return PopupMenuItem<AppLanguage>(
      value: lang,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? const Color(0xFF2A7D8F)
                  : const Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              color: Color(0xFF2A7D8F),
              size: 18,
            ),
        ],
      ),
    );
  }
}