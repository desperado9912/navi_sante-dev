import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controller/facility_bloc.dart';
import '../controller/facility_model.dart';
import '../../home/maps/map_launcher.dart';

// =============================================================================
// facility_grid_card.dart
// lib/features/hospitals/widgets/facility_grid_card.dart
//
// The compact 2-column card shown in the GridView on the Hospitals screen.
// Also reused later (Sprint 8) on the Saved Facilities screen — designed
// to be a self-contained, reusable widget with no screen-specific logic.
//
// LAYOUT (matches the redesigned 2-per-row mockup):
//   ┌─────────────────────┐
//   │ [image]      [book] │  ← bookmark icon overlaid top-right
//   │ [4.9⭐]              │  ← rating badge overlaid top-left
//   ├─────────────────────┤
//   │ Facility Name        │  ← max 2 lines
//   │ [Chip] [Chip] +2      │  ← 2 service chips + overflow count
//   │ [Details →] [↗]      │  ← text button + directions icon button
//   └─────────────────────┘
//
// Only the "Details →" button navigates to the full detail screen.
// Bookmark and directions are independent tap targets on the card.
// =============================================================================

class FacilityGridCard extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onDetailsTap;

  const FacilityGridCard({
    super.key,
    required this.facility,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardImage(facility: facility),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Name ─────────────────────────────────────────────────
                        Text(
                          facility.name,
                          style: const TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            height:     1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // ── Service chips ────────────────────────────────────────
                        _ServiceChipsRow(services: facility.servicesList),
                        const SizedBox(height: 6),
                      ],
                    ),

                    // ── Actions row ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onDetailsTap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00897B),
                              side: const BorderSide(color: Color(0xFF00897B)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Details →',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Directions icon button — opens maps via MapLauncher.
                        _DirectionsIconButton(facility: facility),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}

// =============================================================================
// CARD IMAGE — with rating badge and bookmark icon overlaid
// =============================================================================

class _CardImage extends StatelessWidget {
  final FacilityModel facility;

  const _CardImage({required this.facility});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: AspectRatio(
        aspectRatio: 1.4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image or placeholder ────────────────────────────────────────
            facility.primaryImage != null
                ? CachedNetworkImage(
                    imageUrl:    facility.primaryImage!,
                    fit:         BoxFit.cover,
                    placeholder: (_, _) => _Placeholder(type: facility.type),
                    errorWidget: (_, _, _) => _Placeholder(type: facility.type),
                  )
                : _Placeholder(type: facility.type),

            // ── Rating badge (top-left) ─────────────────────────────────────
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 12),
                    const SizedBox(width: 2),
                    Text(
                      facility.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bookmark icon (top-right) ───────────────────────────────────
            Positioned(
              top: 6,
              right: 6,
              child: _BookmarkButton(facilityId: facility.facilityId),
            ),
          ],
        ),
      ),
    );
  }
}


// =============================================================================
// BOOKMARK BUTTON
// Reads FacilityBloc bookmark state to show filled/outline icon.
// Tapping dispatches ToggleBookmark — optimistic update happens inside the bloc,
// this widget just reflects whatever state it currently holds.
// =============================================================================

class _BookmarkButton extends StatelessWidget {
  final String facilityId;

  const _BookmarkButton({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    // BlocSelector rebuilds only when this facility's bookmark status changes.
    return BlocSelector<FacilityBloc, FacilityState, bool>(
      selector: (state) => state.isBookmarked(facilityId),
      builder: (context, isBookmarked) {
        return GestureDetector(
          // Stop the tap from bubbling up to the card's onTap (no navigation).
          onTap: () => context.read<FacilityBloc>().add(ToggleBookmark(facilityId)),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size:  16,
              color: isBookmarked ? const Color(0xFF00897B) : Colors.grey[700],
            ),
          ),
        );
      },
    );
  }
}


// =============================================================================
// DIRECTIONS ICON BUTTON
// Independent tap target — opens native maps directly from the grid card
// without navigating to the detail screen first.
// =============================================================================

class _DirectionsIconButton extends StatelessWidget {
  final FacilityModel facility;

  const _DirectionsIconButton({required this.facility});

  Future<void> _openDirections(BuildContext context) async {
    try {
      await MapLauncher.openDirections(
        latitude: facility.latitude,
        longitude: facility.longitude,
        facilityName: facility.name,
      );
    } on MapLaunchException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDirections(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:        const Color(0xFF00897B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.directions_rounded, size: 15, color: Colors.white),
      ),
    );
  }
}


// =============================================================================
// SERVICE CHIPS ROW
// Dynamically measures how many service chips fit within the available card
// width using TextPainter, then shows a "+N" overflow indicator for the rest.
// =============================================================================

class _ServiceChipsRow extends StatelessWidget {
  final List<String> services;

  const _ServiceChipsRow({required this.services});

  static const _chipStyle = TextStyle(fontSize: 9, fontWeight: FontWeight.w600);
  static const double _chipHPadding = 12.0; // 6px each side
  static const double _chipSpacing  = 4.0;

  /// Measures the rendered pixel width of a single chip.
  double _measureChipWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _chipStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + _chipHPadding;
  }

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox(height: 18);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        // We will compute which chips go to Row 1 and Row 2.
        List<String> row1 = [];
        List<String> row2 = [];
        int index = 0;

        // Let's fit Row 1
        double row1Width = 0;
        while (index < services.length) {
          final chipWidth = _measureChipWidth(services[index]);
          final gap = row1.isNotEmpty ? _chipSpacing : 0;
          if (row1Width + gap + chipWidth <= maxWidth) {
            row1Width += gap + chipWidth;
            row1.add(services[index]);
            index++;
          } else {
            break;
          }
        }

        // If there are more chips, they go to Row 2 or overflow
        List<String> visibleChips = List.from(row1);
        int overflowCount = 0;

        if (index < services.length) {
          // We have remaining chips. We need to fit them in Row 2,
          // keeping in mind we might need a "+N" overflow chip.
          final remaining = services.sublist(index);
          double row2Width = 0;
          int row2Count = 0;

          for (int i = 0; i < remaining.length; i++) {
            final chipWidth = _measureChipWidth(remaining[i]);
            final gap = row2.isNotEmpty ? _chipSpacing : 0;
            final isLast = (i == remaining.length - 1);

            if (isLast) {
              // If it's the last one, we don't need an overflow indicator if it fits.
              if (row2Width + gap + chipWidth <= maxWidth) {
                row2.add(remaining[i]);
                row2Width += gap + chipWidth;
                row2Count++;
              } else {
                overflowCount = remaining.length - row2Count;
                while (row2.isNotEmpty && row2Width + (row2.length > 1 ? _chipSpacing : 0) + _measureChipWidth('+$overflowCount') > maxWidth) {
                  final removed = row2.removeLast();
                  row2Width -= _measureChipWidth(removed) + (row2.isNotEmpty ? _chipSpacing : 0);
                  overflowCount++;
                }
              }
            } else {
              // Not the last one, so we definitely have remaining/overflow.
              final nextOverflowCount = remaining.length - row2Count - 1;
              final currentOverflowWidth = _measureChipWidth('+$nextOverflowCount');
              if (row2Width + gap + chipWidth + _chipSpacing + currentOverflowWidth <= maxWidth) {
                row2.add(remaining[i]);
                row2Width += gap + chipWidth;
                row2Count++;
              } else {
                overflowCount = remaining.length - row2Count;
                while (row2.isNotEmpty && row2Width + (row2.length > 1 ? _chipSpacing : 0) + _measureChipWidth('+$overflowCount') > maxWidth) {
                  final removed = row2.removeLast();
                  row2Width -= _measureChipWidth(removed) + (row2.isNotEmpty ? _chipSpacing : 0);
                  overflowCount++;
                }
                break;
              }
            }
          }

          visibleChips.addAll(row2);
        }

        // If visible list is empty (should not happen unless screen is extremely narrow), show at least 1
        if (visibleChips.isEmpty && services.isNotEmpty) {
          visibleChips.add(services[0]);
          if (services.length > 1) {
            overflowCount = services.length - 1;
          }
        }

        return Wrap(
          spacing:    _chipSpacing,
          runSpacing: _chipSpacing,
          children: [
            for (final name in visibleChips) _Chip(label: name),
            if (overflowCount > 0) _Chip(label: '+$overflowCount', isOverflow: true),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isOverflow;

  const _Chip({required this.label, this.isOverflow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        isOverflow ? Colors.grey[200] : const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize:   9,
          fontWeight: FontWeight.w600,
          color:      isOverflow ? Colors.grey[600] : const Color(0xFF00897B),
        ),
      ),
    );
  }
}


// =============================================================================
// PLACEHOLDER — shown when no image or while loading
// =============================================================================

class _Placeholder extends StatelessWidget {
  final FacilityType type;

  const _Placeholder({required this.type});

  IconData get _icon => switch (type) {
    FacilityType.hospital => Icons.local_hospital_rounded,
    FacilityType.clinic   => Icons.medical_services_rounded,
    FacilityType.pharmacy => CupertinoIcons.capsule_fill,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF26A69A), Color(0xFF4DB6AC)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(_icon, color: Colors.white.withValues(alpha: 0.8), size: 30),
      ),
    );
  }
}