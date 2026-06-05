import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../controller/map_cubit.dart';
import '../maps/map_service.dart';
import 'map_controls.dart';
import 'header_search.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

// TODO: IMPLEMENT MAP CACHING WITH HIVE

/// Map widget that renders OpenStreetMap with the Carto Light tile layer,
/// displays a pulsing user location dot, and features smooth panning camera transitions.
class HomeMapWidget extends StatefulWidget {
  const HomeMapWidget({super.key});

  @override
  State<HomeMapWidget> createState() => _HomeMapWidgetState();
}

class _HomeMapWidgetState extends State<HomeMapWidget>
    with TickerProviderStateMixin {
  late final MapController _mapController;

  // Dio Instance for tiles request. Caching is handled by FlutterMapCache
  late final Dio _tilesDio;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _tilesDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: MapConfig.tileHeaders,
      ),
    );

    // Trigger map initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MapCubit>().initMap();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _tilesDio.close(force: false);
    super.dispose();
  }

  /// Performs a smooth, animated camera glide to a target [destCenter] and [destZoom].
  void _animatedMapMove(LatLng destCenter, double destZoom) {
    final camera = _mapController.camera;
    final double startLat = camera.center.latitude;
    final double startLng = camera.center.longitude;
    final double startZoom = camera.zoom;

    // Create a temporary animation controller for this movement.
    final AnimationController animationController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    final Animation<double> curve = CurvedAnimation(
      parent: animationController,
      curve: Curves.fastOutSlowIn,
    );

    animationController.addListener(() {
      _mapController.move(
        LatLng(
          startLat + (destCenter.latitude - startLat) * curve.value,
          startLng + (destCenter.longitude - startLng) * curve.value,
        ),
        startZoom + (destZoom - startZoom) * curve.value,
      );
    });

    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animationController.dispose();
      }
    });

    animationController.forward();
  }

  /// Displays a customized descriptive Snackbar for map errors or permissions.
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        duration: const Duration(seconds: 5), // Autodismisses after 5 seconds
        action: SnackBarAction(
          label: 'Settings',
          textColor: const Color(0xFF2A7D8F),
          onPressed: () {
            openAppSettings();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double controlsTopOffset = statusBarHeight + 12 + 54 + 14;

    return BlocListener<MapCubit, MapState>(
      listenWhen: (previous, current) =>
          current.animateToState != previous.animateToState ||
          current.animateToState ||
          current.errorSignal != null,
      listener: (context, state) {
        // Trigger smooth animated glide if requested
        if (state.animateToState) {
          _animatedMapMove(state.center, state.zoom);
        }

        // Display notification if a transient error signal was broadcasted
        if (state.errorSignal != null) {
          _showErrorSnackbar(context, state.errorSignal!);
          context.read<MapCubit>().clearErrorSignal();
        }
      },
      child: BlocBuilder<MapCubit, MapState>(
        builder: (context, state) {
          return Stack(
            children: [
              // Main Map Layer
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: state.center,
                  initialZoom: state.zoom,
                  minZoom: MapConfig.minZoom,
                  maxZoom: MapConfig.maxZoom,
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) {
                      context.read<MapCubit>().updateViewport(
                        camera.center,
                        camera.zoom,
                      );
                    }
                  },
                ),

                children: [
                  // Tile Layer: Carto Light styling with caching
                  TileLayer(
                    urlTemplate: MapConfig.cartoLightUrl,
                    fallbackUrl: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                    subdomains: MapConfig.subdomains,
                    userAgentPackageName: MapConfig.userAgentPackageName,
                    retinaMode: RetinaMode.isHighDensity(context),
                    tileProvider: CachedTileProvider(
                      dio: _tilesDio,
                      store: MemCacheStore(),
                    ),
                  ),

                  // Pulsing Marker for the User Position
                  if (state.userLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: state.userLocation!,
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          child: const PulsingUserLocationMarker(),
                        ),
                      ],
                    ),
                ],
              ),

              // Floating Search Bar
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: HeaderSearch(),
              ),

              // Map Control Panel Overlay
              Positioned(
                right: 16,
                top: controlsTopOffset, // Positioned below search bar
                child: const MapControls(),
              ),

              // //Gps Loading indicator
              // if (state is MapLoadingState)
              //   const Positioned(
              //     bottom: 120,
              //     left: 0,
              //     right: 0,
              //     child: Center(child: _LoadingChip()),
              //   ),
            ],
          );
        },
      ),
    );
  }
}

/// A stunning pulsing marker representing high-accuracy user location.
class PulsingUserLocationMarker extends StatefulWidget {
  const PulsingUserLocationMarker({super.key});

  @override
  State<PulsingUserLocationMarker> createState() =>
      _PulsingUserLocationMarkerState();
}

class _PulsingUserLocationMarkerState extends State<PulsingUserLocationMarker>
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
            // Pulse Halo Ring
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

            // White border ring
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            // Sleek solid indicator dot
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
