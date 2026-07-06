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
// Tapping anywhere on the card (except the bookmark icon and directions
// icon) navigates to the full detail screen.
// =============================================================================

class FacilityGridCard extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onTap;

  const FacilityGridCard({
    super.key,
    required this.facility,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardImage(facility: facility),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
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
                  const SizedBox(height: 8),

                  // ── Actions row ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onTap,
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
                      // Directions icon button — independent tap target,
                      // does not trigger the card's onTap navigation.
                      _DirectionsIconButton(facility: facility),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        try {
          await MapLauncher.openDirections(
            latitude:     facility.latitude,
            longitude:    facility.longitude,
            facilityName: facility.name,
          );
        } on MapLaunchException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      },
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
        // Pre-measure the widest possible overflow chip (e.g. "+99").
        final overflowWidth = _measureChipWidth('+${services.length}');

        double usedWidth = 0;
        int visibleCount = 0;

        for (int i = 0; i < services.length; i++) {
          final chipWidth = _measureChipWidth(services[i]);
          final gap = visibleCount > 0 ? _chipSpacing : 0;
          final remaining = services.length - visibleCount - 1;
          // If more chips follow, reserve space for the "+N" indicator.
          final needed = usedWidth + gap + chipWidth +
              (remaining > 0 ? _chipSpacing + overflowWidth : 0);

          if (needed > maxWidth && visibleCount > 0) break;

          usedWidth += gap + chipWidth;
          visibleCount++;
        }

        // Always show at least 1 chip.
        if (visibleCount == 0) visibleCount = 1;

        final visible  = services.take(visibleCount).toList();
        final overflow = services.length - visibleCount;

        return Wrap(
          spacing:    _chipSpacing,
          runSpacing: _chipSpacing,
          children: [
            for (final name in visible) _Chip(label: name),
            if (overflow > 0) _Chip(label: '+$overflow', isOverflow: true),
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