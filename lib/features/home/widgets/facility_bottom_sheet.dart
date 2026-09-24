import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';
import '../../hospitals/viewmodels/facility_bloc.dart';
import '../../hospitals/data/facility_model.dart';
import '../../hospitals/widgets/facility_details_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../maps/map_launcher.dart';

// FACILITY EXPANDED BOTTOM SHEET
// Shown as a modal bottom sheet when user taps the a facility pin or facility carousel card.
// Call via: FacilityExpandedSheet.show(context, facilityId, userLat, userLng)
// Uses FacilityBloc.state.currentDetail so no extra data fetching is triggered by opening this sheet.
// Shows: image, full name, rating, distance, services chips, phone, hours, address,
// "Get Directions" button, "View Full Details" botton wich navigates to the full FacilityDetailScreen.

class FacilityExpandedSheet extends StatefulWidget {
  final String facilityId;
  final double? userLat;
  final double? userLng;

  const FacilityExpandedSheet({
    super.key,
    required this.facilityId,
    this.userLat,
    this.userLng,
  });

  static Future<void> show(
    BuildContext context,
    String facilityId, {
    double? userLat,
    double? userLng,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        // Pass the existing BLoC instance — do NOT create a new one.
        value: context.read<FacilityBloc>(),
        child: FacilityExpandedSheet(
          facilityId: facilityId,
          userLat: userLat,
          userLng: userLng,
        ),
      ),
    );
  }

  @override
  State<FacilityExpandedSheet> createState() => _FacilityExpandedSheetState();
}

class _FacilityExpandedSheetState extends State<FacilityExpandedSheet> {
  // Snap positions — must mirror the DraggableScrollableSheet config.
  static const double _minSize = 0.00;
  static const double _initialSize = 0.55;
  static const double _maxSize = 0.70;
  static const List<double> _snapSizes = [_initialSize, _maxSize];

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  // Drag-handle gesture helpers
  void _onHandleDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final screenHeight = MediaQuery.of(context).size.height;
    // Dragging up (negative dy) → sheet grows; down (positive dy) → shrinks.
    final delta = -details.delta.dy / screenHeight;
    final newSize = (_sheetController.size + delta).clamp(_minSize, _maxSize);
    _sheetController.jumpTo(newSize);
  }

  /// On finger-up: snap to closest snap position, or close if below threshold.
  void _onHandleDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final currentSize = _sheetController.size;

    // Below the lowest snap → close the sheet entirely.
    if (currentSize < _initialSize * 0.5) {
      Navigator.of(context).pop();
      return;
    }

    // Find the nearest snap position.
    double nearest = _snapSizes.reduce(
      (a, b) => (a - currentSize).abs() < (b - currentSize).abs() ? a : b,
    );

    _sheetController.animateTo(
      nearest,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  // Sheet UI Build Method
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: _snapSizes,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle and Header Buttons
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onHandleDragUpdate,
                onVerticalDragEnd: _onHandleDragEnd,
                child: SizedBox(
                  width: double.infinity,
                  height: 60, // generous hit-target height for buttons
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Drag handle in the center
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Share button on the left
                      Positioned(
                        left: 12,
                        child: BlocBuilder<FacilityBloc, FacilityState>(
                          builder: (context, state) {
                            final detail = state.currentDetail;
                            if (detail == null) return const SizedBox.shrink();

                            return IconButton(
                              icon: const Icon(Icons.ios_share_rounded, size: 30, color: Color(0xFF5F6368)),
                              onPressed: () {
                                final url = MapLauncher.generateShareUrl(
                                  latitude: detail.latitude,
                                  longitude: detail.longitude,
                                  facilityName: detail.name,
                                );
                                SharePlus.instance.share(
                                  ShareParams(text: '${detail.name}\n$url'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      // Close button on the right
                      Positioned(
                        right: 12,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 30, color: Color(0xFF5F6368)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main content area
              Expanded(
                child: BlocBuilder<FacilityBloc, FacilityState>(
                  builder: (context, state) {
                    // Loading
                    if (state.isDetailLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2A7D8F),
                        ),
                      );
                    }

                    // Error
                    if (state.detailStatus == FacilityStatus.error) {
                      return Center(
                        child: Text(
                          state.errorMessage ?? 'Failed to load details.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final detail = state.currentDetail;
                    if (detail == null) return const SizedBox.shrink();

                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero image
                          if (detail.primaryImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: detail.primaryImageUrl!,
                                height: 170,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                memCacheWidth: 800,
                                maxWidthDiskCache: 1200,
                                placeholder: (context, url) => _Placeholder(
                                  type: detail.type,
                                  height: 170,
                                ),
                                errorWidget: (context, url, error) =>
                                    _Placeholder(
                                      type: detail.type,
                                      height: 170,
                                    ),
                              ),
                            )
                          else
                            _Placeholder(type: detail.type, height: 170),

                          const SizedBox(height: 16),

                          // Name + rating
                          Text(
                            detail.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFB300),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                detail.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),

                              // Distance
                              if (widget.userLat != null &&
                                  widget.userLng != null) ...[
                                const SizedBox(width: 12),
                                Text(
                                  '${((detail.latitude - widget.userLat!).abs() * 111000).toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    color: Color(0xFF5F6368),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Services chips
                          if (detail.services.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: detail.services
                                  .take(6)
                                  .map(
                                    (s) => Chip(
                                      label: Text(s),
                                      labelStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      backgroundColor: const Color(0xFFD7EEF3),
                                      side: BorderSide.none,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 0,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],

                          // Contact info
                          const SizedBox(height: 16),
                          if (detail.phone != null)
                            _InfoRow(
                              icon: Icons.phone_rounded,
                              label: detail.phone!,
                            ),
                          if (detail.address != null)
                            _InfoRow(
                              icon: Icons.location_on_rounded,
                              label: detail.address!,
                            ),
                          if (detail.workHours != null)
                            _InfoRow(
                              icon: Icons.access_time_rounded,
                              label: detail.workHours!,
                            ),

                          const SizedBox(height: 20),

                          // GET DIRECTIONS button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                try {
                                  await MapLauncher.openDirections(
                                    latitude: detail.latitude,
                                    longitude: detail.longitude,
                                    facilityName: detail.name,
                                  );
                                } on MapLaunchException catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr(e.message))),
                                  );
                                }
                              },
                              icon: const Icon(Icons.directions_rounded),
                              label: Text(context.tr('GET DIRECTIONS')),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2A7D8F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // VIEW FULL DETAILS button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                final navigator = Navigator.of(context);
                                navigator.pop(); // close sheet first
                                navigator.push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => FacilityDetailScreen(
                                      facilityId: widget.facilityId,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2A7D8F),
                                side: const BorderSide(
                                  color: Color(0xFF2A7D8F),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(context.tr('VIEW FULL DETAILS')),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// SHARED HELPERS — used by ExpandedSheet
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2A7D8F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final FacilityType type;
  final double height;

  const _Placeholder({required this.type, this.height = 64});

  IconData get _icon => switch (type) {
    FacilityType.hospital => Icons.local_hospital_rounded,
    FacilityType.clinic => Icons.medical_services_rounded,
    FacilityType.pharmacy => Icons.local_pharmacy_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
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
          size: 34,
        ),
      ),
    );
  }
}
