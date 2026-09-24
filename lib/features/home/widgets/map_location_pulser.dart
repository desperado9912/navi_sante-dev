import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../viewmodel/map_cubit.dart';

/// Linearly interpolates between two [LatLng] points. Good enough for the
/// short distances covered between consecutive GPS fixes (metres, not
/// kilometres) — great-circle interpolation would be unnecessary overhead
/// here.
class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    final LatLng a = begin!;
    final LatLng b = end!;
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }
}

/// Renders the user's live location as a pulsing marker on the map.
/// Listens to [MapCubit] itself so GPS updates do not rebuild the map screen.
class SmoothUserLocationLayer extends StatelessWidget {
  const SmoothUserLocationLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
      buildWhen: (prev, curr) => prev.userLocation != curr.userLocation,
      builder: (context, state) {
        final LatLng? location = state.userLocation;
        if (location == null) return const SizedBox.shrink();

        return MarkerLayer(
          markers: [
            Marker(
              point: location,
              width: 60,
              height: 60,
              alignment: Alignment.center,
              child: const RepaintBoundary(child: _PulsingUserLocationMarker()),
            ),
          ],
        );
      },
    );
  }
}

/// A pulsing halo + dot marker representing the user's live position on
/// the map.
class _PulsingUserLocationMarker extends StatefulWidget {
  const _PulsingUserLocationMarker();

  @override
  State<_PulsingUserLocationMarker> createState() =>
      _PulsingUserLocationMarkerState();
}

class _PulsingUserLocationMarkerState extends State<_PulsingUserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 14.0, end: 64.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final double opacity = (1.0 - _pulseController.value).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: _pulseAnimation.value,
              height: _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.activeBlue.withValues(
                  alpha: opacity * 0.25,
                ),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: CupertinoColors.activeBlue.withValues(alpha: 0.18),
                  width: 1.2,
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.activeBlue,
              ),
            ),
          ],
        );
      },
    );
  }
}
