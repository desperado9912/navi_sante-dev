import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Immutable model for a language option shown in the picker.
class _LangOption {
  final String code;
  final String label;
  final String flag; // Unicode flag emoji — appropriate for language flags

  const _LangOption({
    required this.code,
    required this.label,
    required this.flag,
  });
}

/// Modal bottom sheet for language selection.
///
/// Returns the selected [code] via [Navigator.pop].
/// The caller is responsible for persisting and applying the selection.
///
/// Example usage:
/// ```dart
/// final code = await showModalBottomSheet<String>(
///   context: context,
///   builder: (_) => LanguageBottomSheet(currentCode: _code),
/// );
/// ```
class LanguageBottomSheet extends StatelessWidget {
  final String currentCode;

  const LanguageBottomSheet({super.key, required this.currentCode});

  static const _options = [
    _LangOption(code: 'en', label: 'English',  flag: '🇬🇧'),
    _LangOption(code: 'fr', label: 'Français', flag: '🇫🇷'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 16,
                      color: Color(0xFF555552),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Language options ──────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(_options.length, (i) {
                final option    = _options[i];
                final isSelected = option.code == currentCode;
                final isLast    = i == _options.length - 1;

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(option.code),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            // Flag circle
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2A7D8F).withOpacity(0.12)
                                    : const Color(0xFFEEEEEE),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Center(
                                child: Text(
                                  option.flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Language label
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF2A7D8F)
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),

                            // Checkmark for selected option
                            if (isSelected)
                              const Icon(
                                CupertinoIcons.checkmark_alt,
                                color: Color(0xFF2A7D8F),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        indent: 74,
                        color: Color(0xFFE8E8E8),
                      ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}