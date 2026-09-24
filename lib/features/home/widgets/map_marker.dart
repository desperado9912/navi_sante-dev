import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../hospitals/data/facility_model.dart';

// Custom pin widget rendered on the map for each facility.
// Used inside flutter_map's Marker.child parameter.

class FacilityMapMarker extends StatelessWidget {
  final FacilityType type;

  // isSelected: true when user taps the pin change state.
  final bool isSelected;

  const FacilityMapMarker({
    super.key,
    required this.type,
    this.isSelected = false,
  });

  // Pin color: Normal: Vibrant Medical Red (0xFFE53935), Selected: NaviSanté Theme Teal (0xFF2A7D8F).
  Color get _pinColor =>
      isSelected ? const Color(0xFF2A7D8F) : const Color(0xFFE53935);

  // Pin icon: Hospital/Clinic: 'H' (FontAwesomeIcons.h), Pharmacy: Rod of Asclepius (FontAwesomeIcons.staffSnake).
  FaIconData get _iconData {
    return switch (type) {
      FacilityType.pharmacy => FontAwesomeIcons.staffSnake,
      FacilityType.hospital || FacilityType.clinic => FontAwesomeIcons.h,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double headSize = isSelected ? 40.0 : 34.0;
    final double iconSize = isSelected ? 18.0 : 15.0;

    return AnimatedScale(
      scale: isSelected ? 1.18 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium Circle head
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: headSize,
            height: headSize,
            decoration: BoxDecoration(
              color: _pinColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 2.5 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF2A7D8F).withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.28),
                  blurRadius: isSelected ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: FaIcon(
                _iconData,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),

          // // Tip points downward to exact map coordinate.
          // AnimatedContainer(
          //   duration: const Duration(milliseconds: 220),
          //   width: 12,
          //   height: 7,
          //   child: CustomPaint(
          //     size: const Size(12, 7),
          //     painter: _PinTipPainter(color: _pinColor),
          //   ),
          // ),
        ],
      ),
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
    final String label = count > 99 ? '99+' : count.toString();

    return SizedBox.square(
      dimension: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFF8F6),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A7D8F), Color(0xFFE53935)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 1,
              ),
            ),
          ),
          Positioned(
            top: 9,
            child: Icon(
              Icons.local_hospital_rounded,
              color: Colors.white.withValues(alpha: 0.82),
              size: 13,
            ),
          ),
          Positioned(
            bottom: 9,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: label.length > 2 ? 11 : 13,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ],
      ),
    );
  }
}

// Pin's tip custom painter animation
// class _PinTipPainter extends CustomPainter {
//   final Color color;

//   const _PinTipPainter({required this.color});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = color
//       ..style = PaintingStyle.fill;

//     // Triangle point at bottom centre.
//     final path = Path()
//       ..moveTo(0, 0)
//       ..lineTo(size.width, 0)
//       ..lineTo(size.width / 2, size.height)
//       ..close();

//     canvas.drawPath(path, paint);
//   }

//   @override
//   bool shouldRepaint(_PinTipPainter old) => old.color != color;
// }
