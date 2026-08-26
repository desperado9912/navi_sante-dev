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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardImage(facility: facility),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── Top content group (name + chips) ─────────────────
                  // Flexible + ClipRect: defensive net — content shrinks
                  // gracefully on very small screens, never overflows.
                  Flexible(
                    child: ClipRect(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Name (max 2 lines overflow ellipsis) ──────
                          Text(
                            facility.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // ── Service chips ─────────────────────────────
                          _ServiceChipsRow(
                            services: facility.servicesList,
                            totalCount: facility.servicesCount,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Actions row ────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDetailsTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2A7D8F),
                            side: const BorderSide(color: Color(0xFF2A7D8F)),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Details →',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Directions icon button — opens maps via [MapLauncher].
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
                    imageUrl: facility.primaryImage!,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    maxWidthDiskCache: 720,
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
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB300),
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      facility.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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

class _BookmarkButton extends StatefulWidget {
  final String facilityId;

  const _BookmarkButton({required this.facilityId});

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  /// Tap cooldown — prevents rapid duplicate events from reaching the bloc.
  /// 300ms matches the bloc-level debounce window.
  bool _cooldown = false;

  void _onTap() {
    if (_cooldown) return;
    setState(() => _cooldown = true);
    context.read<FacilityBloc>().add(ToggleBookmark(widget.facilityId));
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _cooldown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // BlocSelector rebuilds only when this facility's bookmark status changes.
    return BlocSelector<FacilityBloc, FacilityState, bool>(
      selector: (state) => state.isBookmarked(widget.facilityId),
      builder: (context, isBookmarked) {
        return GestureDetector(
          // Stop the tap from bubbling up to the card's onTap (no navigation).
          onTap: _onTap,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 16,
              color: isBookmarked ? const Color(0xFF2A7D8F) : Colors.grey[700],
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDirections(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A7D8F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.directions_rounded,
          size: 15,
          color: Colors.white,
        ),
      ),
    );
  }
}

// =============================================================================
// SERVICE CHIPS ROW
// Dynamically measures how many service chips fit within the available card
// width using TextPainter, then shows a "+N" overflow indicator for the rest.
//   1. Greedily pack chip labels into lines, mimicking Wrap's own
//      line-breaking, stopping once 2 lines are full.
//   2. If items remain after 2 lines, or the DB reports more services than
//      we even received (services_count > services.length), we need an
//      overflow chip. Pop chips off the END of the last line — recomputing
//      the overflow count using the REAL total each time — until the "+N"
//      chip physically fits alongside what's left.
//   3. Wrapped in a fixed-height, hard-clipped SizedBox: a defensive net
//      that guarantees the card can never grow taller than 2 chip lines,
//      even in a font-metrics edge case this algorithm didn't anticipate.
// =============================================================================

class _ServiceChipsRow extends StatelessWidget {
  final List<String> services;
  final int totalCount;

  const _ServiceChipsRow({required this.services, required this.totalCount});

  static const _chipStyle = TextStyle(fontSize: 9, fontWeight: FontWeight.w600);
  static const double _chipHPadding = 12.0; // 6px each side
  static const double _chipSpacing = 4.0;
  static const double _chipHeight =
      17.0; // measured: 9px text + 2*2px vertical padding + line height slack
  static const double _lineGap = 4.0; // gap between lines 1 and 2

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
    if (services.isEmpty) return const SizedBox(height: _chipHeight);

    return SizedBox(
      // Cap service chips to exactly 2 lines no matter what the packing algorithm decides.
      height: (_chipHeight * 2) + _lineGap,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final chips = _pack(maxWidth);

            return Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: _chipSpacing,
                runSpacing: _lineGap,
                children: chips,
              ),
            );
          },
        ),
      ),
    );
  }

  // Packs Service chips as fit into 2 lines, appending an accurate
  /// "+N" chip if any services remain (using [totalCount]).
  List<Widget> _pack(double maxWidth) {
    final lines = <List<String>>[[]];
    double lineWidth = 0;

    for (final label in services) {
      final chipWidth = _measureChipWidth(label);
      final gap = lines.last.isEmpty ? 0 : _chipSpacing;

      if (lineWidth + gap + chipWidth <= maxWidth) {
        lines.last.add(label);
        lineWidth += gap + chipWidth;
        continue;
      }

      if (lines.length < 2) {
        lines.add([label]);
        lineWidth = chipWidth;
      } else {
        break;
      }
    }

    final shown = lines.expand((l) => l).toList();
    var overflow = totalCount - shown.length;

    if (overflow <= 0) {
      return [for (final s in shown) _Chip(label: s)];
    }

    // Reserves last line space for the +N chips indicator
    // Evitcs non fitting trailing chips (except if they fit)
    final lastLine = lines.last;
    double lastLineWidth = 0;
    for (var i = 0; i < lastLine.length; i++) {
      lastLineWidth +=
          _measureChipWidth(lastLine[i]) + (i == 0 ? 0 : _chipSpacing);
    }

    while (lastLine.isNotEmpty &&
        lastLineWidth + _chipSpacing + _measureChipWidth('+$overflow') >
            maxWidth) {
      final removed = lastLine.removeLast();
      lastLineWidth -=
          _measureChipWidth(removed) + (lastLine.isEmpty ? 0 : _chipSpacing);
      overflow++;
    }

    final finalChips = [
      for (final l in lines.sublist(0, lines.length - 1)) ...l,
      ...lastLine,
    ];

    return [
      for (final s in finalChips) _Chip(label: s),
      _Chip(label: '+$overflow', isOverflow: true),
    ];
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
        color: isOverflow ? Colors.grey[200] : const Color(0xFFD7EEF3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isOverflow ? Colors.grey[600] : const Color(0xFF2A7D8F),
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
    FacilityType.clinic => Icons.medical_services_rounded,
    FacilityType.pharmacy => CupertinoIcons.capsule_fill,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF26A69A), Color(0xFF2A7D8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _icon,
          color: Colors.white.withValues(alpha: 0.8),
          size: 30,
        ),
      ),
    );
  }
}
