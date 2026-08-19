import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../hospitals/controller/facility_bloc.dart';
import '../controller/map_cubit.dart';
import '../controller/map_cache_manager.dart';
import 'map_service.dart';
import '../widgets/map_marker.dart';
import '../widgets/map_controls.dart';
import '../widgets/header_search_bar.dart';
import '../widgets/facility_carousel.dart';
import '../widgets/facility_bottom_sheet.dart';

/// Map widget that holds together and renders all main map features and widgets
/// [HomeScreen] builds this widget.
/// The widget builds the following features:
/// => OSM Carto map tile initilization, Map Animation,
/// => Map Error snackbar, Floating Search bar, map controls, facility carousel,
/// => User location pulsing indicator, marker clustering, facility markers,
/// => Smooth camera transitions
///
/// TODO: MOVE PULSING INDICATOR TO ITS OWN WIDGET FILE & CONFIGURATION WITH SMOOTH ANIMATION. THAT BUILDS IN THIS ONE.

class HomeMapWidget extends StatefulWidget {
  const HomeMapWidget({super.key});

  @override
  State<HomeMapWidget> createState() => _HomeMapWidgetState();
}

class _HomeMapWidgetState extends State<HomeMapWidget>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final Dio _tilesDio;

  // Map tile request instance. Map caching is handled by cache manager with Hive storage.
  CacheStore? _hiveCacheStore;

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

    // Initialize Hive cache store (skipped on web — no temp directory support)
    try {
      _hiveCacheStore = MapCacheManager.instance.store;
    } catch (_) {
      _hiveCacheStore = null;
    }

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
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        duration: const Duration(seconds: 4), // Autodismisses after 4 seconds
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
          current.errorSignal != null ||
          current.userLocation != previous.userLocation,
      listener: (context, state) {
        // Dismiss snackbar when location is successfully found
        if (state is MapLocatedState && state.userLocation != null) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
        }

        // Trigger smooth animated glide if requested
        if (state.animateToState) {
          _animatedMapMove(state.center, state.zoom);
        }

        // Display notification if a transient error signal was broadcasted
        if (state.errorSignal != null) {
          _showErrorSnackbar(context, state.errorSignal!);
          context.read<MapCubit>().clearErrorSignal();
        }

        // Fetch highlights when user's location is resolved/updated
        if (state.userLocation != null) {
          context.read<FacilityBloc>().add(
            LoadHighlights(
              userLat: state.userLocation!.latitude,
              userLng: state.userLocation!.longitude,
            ),
          );
        }
      },
      child: BlocBuilder<MapCubit, MapState>(
        buildWhen: (prev, current) =>
            prev.animateToState != current.animateToState ||
            prev.userLocation != current.userLocation ||
            prev.interactionState != current.interactionState ||
            current is MapErrorState,
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
                  onTap: (tapPosition, point) {
                    context.read<MapCubit>().returnToIdle();
                    context.read<FacilityBloc>().add(ClearSearch());
                  },
                ),

                // Tile Layer: Carto Light styling with caching
                children: [
                  if (_hiveCacheStore != null)
                    TileLayer(
                      urlTemplate: MapConfig.cartoLightUrl,
                      fallbackUrl:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                      subdomains: MapConfig.subdomains,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      retinaMode: RetinaMode.isHighDensity(context),
                      tileProvider: CachedTileProvider(
                        dio: _tilesDio,
                        // Tiles stored in Hive cache
                        store: _hiveCacheStore!,
                        maxStale: MapCacheManager.cacheTtl,
                      ),
                    )
                  else
                    // If hive not ready render tiles without caching
                    TileLayer(
                      urlTemplate: MapConfig.cartoLightUrl,
                      fallbackUrl:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                      subdomains: MapConfig.subdomains,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      retinaMode: RetinaMode.isHighDensity(context),
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

                  // Facility Map Pins
                  BlocBuilder<FacilityBloc, FacilityState>(
                    buildWhen: (prev, curr) =>
                        prev.facilities != curr.facilities,
                    builder: (context, facilityState) {
                      if (facilityState.facilities.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final selectedFacilityId =
                          state.interactionState is MapPinSelected
                          ? (state.interactionState as MapPinSelected).facilityId
                          : state.interactionState is MapDetailSheet
                              ? (state.interactionState as MapDetailSheet).facilityId
                              : null;

                      final markers = facilityState.facilities.map((facility) {
                        return Marker(
                          point: LatLng(facility.latitude, facility.longitude),
                          width: 34,
                          height: 41,
                          alignment: Alignment.bottomCenter,
                          child: GestureDetector(
                            onTap: () async {
                              context.read<FacilityBloc>().add(
                                LoadFacilityDetail(facility.facilityId),
                              );
                              context.read<MapCubit>().expandSheet(facility.facilityId);
                              await FacilityExpandedSheet.show(
                                context,
                                facility.facilityId,
                                userLat: state.userLocation?.latitude,
                                userLng: state.userLocation?.longitude,
                              );
                              if (context.mounted) {
                                context.read<MapCubit>().returnToIdle();
                              }
                            },
                            child: FacilityMapMarker(
                              type: facility.type,
                              isSelected:
                                  facility.facilityId == selectedFacilityId,
                            ),
                          ),
                        );
                      }).toList();

                      // MarkerClusterLayerWidget groups nearby pins at low zoom.
                      // At higher zoom they separate back into individual pins.
                      return MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 45,
                          size: const Size(40, 40),
                          alignment: Alignment.center,
                          markers: markers,
                          builder: (context, clusterMarkers) =>
                              FacilityClusterMarker(
                                count: clusterMarkers.length,
                              ),
                        ),
                      );
                    },
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

              // Overlays (Carousel card) based on MapInteractionState
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                left: 0,
                right: 0,
                child: _buildBottomOverlay(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomOverlay(BuildContext context, MapState state) {
    final interaction = state.interactionState;

    if (interaction is MapIdle) {
      if (state.userLocation != null) {
        return HighlightsCarousel(
          userLat: state.userLocation!.latitude,
          userLng: state.userLocation!.longitude,
          onCardTap: (facility) async {
            context.read<FacilityBloc>().add(
              LoadFacilityDetail(facility.facilityId),
            );
            context.read<MapCubit>().expandSheet(facility.facilityId);
            await FacilityExpandedSheet.show(
              context,
              facility.facilityId,
              userLat: state.userLocation?.latitude,
              userLng: state.userLocation?.longitude,
            );
            if (context.mounted) {
              context.read<MapCubit>().returnToIdle();
            }
          },
        );
      }
    }

    return const SizedBox.shrink();
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
