import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:navi_sante/core/utils/language_cubit/language_cubit.dart';

// =============================================================================
// facility_filter_bar.dart
// lib/features/hospitals/widgets/facility_filter_bar.dart
//
// The 2x2 filter grid below the search bar:
//   Row 1: [Health Condition ▾]  [Select City ▾]
//   Row 2: [Price Rating ▾]      [Search button]
//
// This widget is PRESENTATIONAL ONLY — it holds local UI state for the
// selected dropdown values, but does not call the BLoC or repository itself.
// The parent (hospitals_screen.dart) owns the data fetching (service list)
// and the search dispatch logic. This keeps the widget reusable and easy
// to test in isolation.
//
// onApply is called only when the user taps the "Search" button — dropdown
// selections alone do not trigger a search, matching the mockup's explicit
// Search button.
// =============================================================================

class FacilityFilterBar extends StatefulWidget {
  // Service names fetched by the parent via FacilityRepository.getServiceOptions().
  // Passed in rather than fetched here — keeps this widget free of network calls.
  final List<String> serviceOptions;

  // Called when the user taps "Search". All three values are nullable —
  // null means "no filter on this dimension".
  final void Function({
    String? service,
    String? city,
    String? priceRange,
  }) onApply;

  const FacilityFilterBar({
    super.key,
    required this.serviceOptions,
    required this.onApply,
  });

  @override
  State<FacilityFilterBar> createState() => _FacilityFilterBarState();
}

class _FacilityFilterBarState extends State<FacilityFilterBar> {
  // Hardcoded for MVP — Cameroon's main cities. Low cardinality, rarely
  // changes, not worth a database round trip or a dedicated lookup table.
  static const List<String> _cities = [
    'Yaoundé', 'Douala', 'Bafoussam', 'Bamenda',
    'Garoua', 'Maroua', 'Buea', 'Kribi',
  ];

  // Maps the user-facing label to the database value stored in price_range.
  static const Map<String, String> _priceRangeOptions = {
    'Free':       'free',
    'Low':        'low',  
    'Affordable': 'affordable',
    'High':       'high',
  };

  String? _selectedService;
  String? _selectedCity;
  String? _selectedPriceLabel; // display label, e.g. 'Affordable'

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color:        Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // ── Row 1: Health Condition + City ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _PlatformAdaptiveDropdown(
                  hint:    'Health Condition',
                  value:   _selectedService,
                  items:   widget.serviceOptions,
                  onChanged: (v) => setState(() => _selectedService = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlatformAdaptiveDropdown(
                  hint:    'Select City',
                  value:   _selectedCity,
                  items:   _cities,
                  onChanged: (v) => setState(() => _selectedCity = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Row 2: Price Rating + Search button ───────────────────────────
          Row(
            children: [
              Expanded(
                child: _PlatformAdaptiveDropdown(
                  hint:    'Price Rating',
                  value:   _selectedPriceLabel,
                  items:   _priceRangeOptions.keys.toList(),
                  onChanged: (v) => setState(() => _selectedPriceLabel = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () => widget.onApply(
                      service:    _selectedService,
                      city:       _selectedCity,
                      // Convert display label back to DB value before
                      // calling the parent — parent and BLoC never see
                      // the capitalised label, only 'free'/'affordable'/'premium'.
                      priceRange: _selectedPriceLabel == null
                          ? null
                          : _priceRangeOptions[_selectedPriceLabel],
                    ),
                    icon:  const Icon(CupertinoIcons.search, size: 18),
                    label: Text(context.tr('Search')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2A7D8F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// =============================================================================
// PLATFORM-ADAPTIVE DROPDOWN
// iOS/macOS → CupertinoActionSheet bottom picker on tap.
// Android/others → Material DropdownButton (unchanged).
// =============================================================================

class _PlatformAdaptiveDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _PlatformAdaptiveDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  bool _isCupertino(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    return _isCupertino(context)
        ? _buildCupertinoDropdown(context)
        : _buildMaterialDropdown(context);
  }

  // ── Cupertino: tappable container → CupertinoActionSheet ──────────────────
  Widget _buildCupertinoDropdown(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCupertinoSheet(context),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null ? context.tr(value!) : context.tr(hint),
                style: TextStyle(
                  fontSize: 12,
                  color: value != null ? Colors.black87 : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  void _showCupertinoSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.tr(hint)),
        actions: [
          // "All" option clears the selection.
          CupertinoActionSheetAction(
            isDefaultAction: value == null,
            onPressed: () {
              onChanged(null);
              Navigator.pop(ctx);
            },
            child: Text(context.tr('All')),
          ),
          ...items.map(
            (item) => CupertinoActionSheetAction(
              isDefaultAction: item == value,
              onPressed: () {
                onChanged(item);
                Navigator.pop(ctx);
              },
              child: Text(context.tr(item)),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.tr('Cancel')),
        ),
      ),
    );
  }

  // ── Material: standard DropdownButton (existing behaviour) ────────────────
  Widget _buildMaterialDropdown(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:           value,
          hint:            Text(context.tr(hint), style: const TextStyle(fontSize: 12)),
          isExpanded:      true,
          icon:            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style:           const TextStyle(fontSize: 12, color: Colors.black87),
          // Allows clearing a selection by re-selecting the current value's
          // "None" option — implemented by prepending a clear entry.
          items: [
            DropdownMenuItem(value: null, child: Text(context.tr('All'))),
            ...items.map((item) => DropdownMenuItem(value: item, child: Text(context.tr(item)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}