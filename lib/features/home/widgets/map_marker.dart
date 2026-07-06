import 'package:flutter/material.dart';
import '../../hospitals/controller/facility_model.dart';

// Custom pin widget rendered on the map for each facility.
// Used inside flutter_map's Marker.child parameter.
// TODO: CHANGE OVERALL DESING
// TODO: CHANGE IS SELECTED COLOR & ICONS

class FacilityMapMarker extends StatelessWidget {
  final FacilityType type;

  // isSelected: true when user taps the pin change state.
  final bool isSelected;

  const FacilityMapMarker({
    super.key,
    required this.type,
    this.isSelected = false,
  });

  // Pin color: Normal: red, Selected: amber.
  Color get _pinColor =>
      isSelected ? const Color(0xFFFFB300) : const Color(0xFFE53935);

  // Pin icon: Hospital: 'H', Pharmacy: rod of asclepius symbol: '⚕'.
  String get _symbol {
    return switch (type) {
      FacilityType.pharmacy => '⚕',
      FacilityType.hospital || FacilityType.clinic => 'H',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle head
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _pinColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _symbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                // Prevents symbol from scaling with device text size settings.
                height: 1,
              ),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),

        // Tip points downward to map coordinate.
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 0,
          height: 0,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: CustomPaint(
            size: const Size(12, 7),
            painter: _PinTipPainter(color: _pinColor),
          ),
        ),
      ],
    );
  }
}

// Cluster marker shown when multiple pins are close together.
// Displays the count of grouped facilities inside a red circle.

class FacilityClusterMarker extends StatelessWidget {
  final int count;

  const FacilityClusterMarker({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

// Pin's tip custom painter animation

class _PinTipPainter extends CustomPainter {
  final Color color;

  const _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Triangle point at bottom centre.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTipPainter old) => old.color != color;
}
