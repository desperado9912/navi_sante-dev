import 'package:flutter/material.dart';

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
    'Garoua', 'Maroua', 'Buea', 'Kribi', ''
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
      padding: const EdgeInsets.all(12),
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
                child: _Dropdown(
                  hint:    'Health Condition',
                  value:   _selectedService,
                  items:   widget.serviceOptions,
                  onChanged: (v) => setState(() => _selectedService = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Dropdown(
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
                child: _Dropdown(
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
                    icon:  const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Search'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
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
// DROPDOWN — shared styling for all three filter dropdowns
// =============================================================================
// TODO: USE A MORE MODERN OR CUPERTINO IOS STYLE DROPDOWN

class _Dropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:           value,
          hint:            Text(hint, style: const TextStyle(fontSize: 12)),
          isExpanded:      true,
          icon:            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style:           const TextStyle(fontSize: 12, color: Colors.black87),
          // Allows clearing a selection by re-selecting the current value's
          // "None" option — implemented by prepending a clear entry.
          items: [
            const DropdownMenuItem(value: null, child: Text('All')),
            ...items.map((item) => DropdownMenuItem(value: item, child: Text(item))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}