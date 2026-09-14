import 'package:flutter/material.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';

/// Renders PharmacyState.mergedQuickFilters as tappable chips. Doesn't
/// distinguish visually between "recent" and "common" chips — per your
/// call to merge them into one row — but the active one (matching the
/// current search query) is highlighted so the user can see what's live.
class QuickFilterChips extends StatelessWidget {
  final List<String> filters;
  final String activeFilter;
  final bool canClear;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  const QuickFilterChips({
    super.key,
    required this.filters,
    required this.activeFilter,
    required this.canClear,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('Quick Filters:'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            if (canClear)
              GestureDetector(
                onTap: onClear,
                child: Text(
                  context.tr('Clear'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2A7D8F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 78),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: filters.map((filter) {
                final bool isActive =
                    filter.toLowerCase() == activeFilter.toLowerCase();
                return GestureDetector(
                  onTap: () => onTap(filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2A7D8F)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      context.tr(filter),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}