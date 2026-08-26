import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hospitals/controller/facility_bloc.dart';
import '../../hospitals/controller/facility_model.dart';

// Floating horizontal carousel showing the 5 closest facilities to the user.
// Sits above the bottom navigation bar, overlaying the map.
// map states handles if the carousel should be displayed or not.
// onCardTap: called when user taps a card. Parent handles the MapCubit
// state transition (MapIdle → MapDetailSheet) and FacilityBloc detail load.

class HighlightsCarousel extends StatelessWidget {
  final double userLat;
  final double userLng;
  final void Function(FacilityModel facility) onCardTap;

  const HighlightsCarousel({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FacilityBloc, FacilityState>(
      // Only rebuild when highlights list changes — skip all other state changes.
      buildWhen: (prev, curr) => prev.highlights != curr.highlights,
      builder: (context, state) {
        // Nothing to show: no data yet or all facilities too far.
        if (state.highlights.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 146,
          child: ListView.separated(
            key: const PageStorageKey<String>('highlights_carousel_list'),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.highlights.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return FacilityCardUI(
                facility: state.highlights[index],
                userLat: userLat,
                userLng: userLng,
                onTap: () => onCardTap(state.highlights[index]),
              );
            },
          ),
        );
      },
    );
  }
}

// Single facility card displayed in the carousel position when a pin or search suggestion is selected.
class SelectedFacilityCard extends StatelessWidget {
  final FacilityModel facility;
  final double? userLat;
  final double? userLng;
  final void Function(FacilityModel facility) onCardTap;

  const SelectedFacilityCard({
    super.key,
    required this.facility,
    this.userLat,
    this.userLng,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FacilityCardUI(
            facility: facility,
            userLat: userLat,
            userLng: userLng,
            onTap: () => onCardTap(facility),
          ),
        ),
      ),
    );
  }
}

// Carousel FacilityCard UI
// Shows: image, name, type badge and distance.
// Size is fixed so cards have consistent width regardless of facility name length.

class FacilityCardUI extends StatelessWidget {
  final FacilityModel facility;
  final double? userLat;
  final double? userLng;
  final VoidCallback onTap;

  const FacilityCardUI({
    super.key,
    required this.facility,
    this.userLat,
    this.userLng,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceStr = userLat != null && userLng != null
        ? facility.formatDistance(userLat!, userLng!)
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 72,
                width: double.infinity,
                child: facility.primaryImage != null
                    ? CachedNetworkImage(
                        imageUrl: facility.primaryImage!,
                        fit: BoxFit.cover,

                        // Shimmer-like placeholder while image loads.
                        placeholder: (_, _) =>
                            _FacilityPlaceholder(type: facility.type),
                        errorWidget: (_, _, _) =>
                            _FacilityPlaceholder(type: facility.type),
                      )
                    : _FacilityPlaceholder(type: facility.type),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name — Section with strict height constraint protection.
                    Text(
                      facility.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Type badge + distance on same row.
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TypeBadge(type: facility.type),
                        const Spacer(),
                        if (distanceStr.isNotEmpty)
                          Text(
                            distanceStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TYPE BADGE Helper
// Small coloured label showing 'Hospital', 'Clinic', or 'Pharmacy'.
class _TypeBadge extends StatelessWidget {
  final FacilityType type;

  const _TypeBadge({required this.type});

  String get _label => switch (type) {
    FacilityType.hospital => 'Hospital',
    FacilityType.clinic => 'Clinic',
    FacilityType.pharmacy => 'Pharmacy',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFD7EEF3).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Color(0xFF2A7D8F),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// FACILITY PLACEHOLDER
// Placeholder image shown when a facility has no image or while the image is loading.
// Uses a teal gradient with the facility-appropriate icon.
// Never shows a broken image — always a clean fallback.

class _FacilityPlaceholder extends StatelessWidget {
  final FacilityType type;

  const _FacilityPlaceholder({required this.type});

  IconData get _icon => switch (type) {
    FacilityType.hospital => Icons.local_hospital_rounded,
    FacilityType.clinic => Icons.medical_services_rounded,
    FacilityType.pharmacy => Icons.local_pharmacy_rounded,
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
          size: 28,
        ),
      ),
    );
  }
}
