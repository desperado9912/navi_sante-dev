import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/facility_model.dart';

// lib/features/hospitals/widgets/detail_image_carousel.dart
//
// Swipeable image carousel for the detail screen.
// Shows a placeholder if the facility has no images yet.

class DetailImageCarousel extends StatefulWidget {
  final List<FacilityImage> images;
  final FacilityType fallbackType;

  const DetailImageCarousel({
    super.key,
    required this.images,
    required this.fallbackType,
  });

  @override
  State<DetailImageCarousel> createState() => _DetailImageCarouselState();
}

class _DetailImageCarouselState extends State<DetailImageCarousel> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return _ImagePlaceholder(type: widget.fallbackType);
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: widget.images[index].url,
              fit: BoxFit.cover,
              width: double.infinity,
              memCacheWidth: 800,
              maxWidthDiskCache: 1200,
              placeholder: (_, _) => _ImagePlaceholder(type: widget.fallbackType),
              errorWidget: (_, _, _) => _ImagePlaceholder(type: widget.fallbackType),
            );
          },
        ),

        // Dot indicators — only shown when there's more than one image.
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.images.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// Shown when a facility has no photos, or while an image is loading/fails.
class _ImagePlaceholder extends StatelessWidget {
  final FacilityType type;
  const _ImagePlaceholder({required this.type});

  IconData get _icon => switch (type) {
    FacilityType.hospital => Icons.local_hospital_rounded,
    FacilityType.clinic => Icons.medical_services_rounded,
    FacilityType.pharmacy => Icons.local_pharmacy_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF26A69A), Color(0xFF2A7D8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(_icon, color: Colors.white.withValues(alpha: 0.85), size: 48),
      ),
    );
  }
}