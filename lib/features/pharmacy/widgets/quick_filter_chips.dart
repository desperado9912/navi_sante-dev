import 'package:flutter/material.dart';

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
            const Text(
              'Quick Filters:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            if (canClear)
              GestureDetector(
                onTap: onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF2A7D8F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((filter) {
            final bool isActive =
                filter.toLowerCase() == activeFilter.toLowerCase();
            return GestureDetector(
              onTap: () => onTap(filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF2A7D8F)
                      : const Color(0xFFD8F6FF).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF2A7D8F),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}