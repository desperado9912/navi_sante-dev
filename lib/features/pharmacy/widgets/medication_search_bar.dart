import 'package:flutter/material.dart';

/// Pharmacy screen's search field. Purely presentational — debouncing and
/// dispatching SearchMedications live in the parent screen, not here, so
/// this widget stays trivially reusable/testable.
class MedicationSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const MedicationSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F6FF).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF2A7D8F), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: "Try searching 'Malaria' or 'Ibuprofen'",
                hintStyle: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          // Bound directly to the controller (a ValueListenable) rather
          // than a parent setState — cheap and avoids rebuilding
          // anything above this widget just to toggle one icon.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF5F6368),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}