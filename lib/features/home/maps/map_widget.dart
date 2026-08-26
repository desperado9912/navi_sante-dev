import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../hospitals/controller/facility_bloc.dart';
import '../../hospitals/controller/facility_model.dart';
import '../controller/map_cubit.dart';
import '../controller/map_cache_manager.dart';
import 'map_service.dart';
import 'tile_prefetch.dart';
import '../widgets/map_marker.dart';
import '../widgets/map_controls.dart';
import '../widgets/header_search_bar.dart';
import '../widgets/facility_carousel.dart';
import '../widgets/facility_bottom_sheet.dart';
import '../widgets/map_location_pulser.dart';

/// Map widget that holds together and renders all main map features and widgets
/// [HomeScreen] builds this widget.
/// The widget builds the following features:
/// => OSM Carto map tile initilization, Map Animation,
/// => Map Error snackbar, Floating Search bar, map controls, facility carousel,
/// => User location pulsing indicator, marker clustering, facility markers,
/// => Smooth camera transitions

class HomeMapWidget extends StatefulWidget {
  const HomeMapWidget({super.key});

  @override
  State<HomeMapWidget> createState() => _HomeMapWidgetState();
}

class _HomeMapWidgetState extends State<HomeMapWidget>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  final Map<TileZoomBand, Dio> _tileDios = {};
  TilePrefetchService? _preFetchService;
  final Distance _distance = const Distance();
  LatLng? _lastHighlightsLocation;
  DateTime? _lastHighlightsLoadedAt;

  // True once every zoom-band cache store is open and safe to read from.
  bool _cacheReady = false;

  final GlobalKey<HeaderSearchState> _headerSearchKey =
      GlobalKey<HeaderSearchState>();
  FacilityModel? _selectedFacility;

  @override
  void initState() {
    super.initState();

    _mapController = MapController();

    // Sync path: cache was already opened in main.dart — zero delay.
    // Async fallback: only if main.dart init somehow failed or is still in-flight.
    if (!kIsWeb && MapCacheManager.instance.isReady) {
      _activateCachedTileLayers();
    } else if (!kIsWeb) {
      _initTileCacheAsync();
    }

    // Trigger map initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MapCubit>().initMap();
    });
  }

  /// Synchronously activates cached tile Dio instances and prefetch service.
  /// Called when MapCacheManager is already ready (the normal path).
  void _activateCachedTileLayers() {
    for (final TileZoomBand band in TileZoomBand.values) {
      _tileDios[band] = _createTileDio();
    }
    _preFetchService = TilePrefetchService();
    _cacheReady = true;
  }

  /// Async fallback: only used if the cache wasn't ready in initState.
  Future<void> _initTileCacheAsync() async {
    try {
      await MapCacheManager.instance.initialize();
      if (!mounted) return;
      _activateCachedTileLayers();
      setState(() {});
    } catch (_) {
      // Falls through to the uncached TileLayer below — still renders,
      // just without persistence, rather than crashing the map screen.
    }
  }

  Dio _createTileDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: Map.of(MapConfig.tileHeaders),
      ),
    );
  }

  AnimationController? _moveController;

  @override
  void dispose() {
    _moveController?.stop();
    _moveController?.dispose();
    _moveController = null;
    _preFetchService?.dispose();
    _mapController.dispose();
    for (final Dio dio in _tileDios.values) {
      dio.close(force: false);
    }
    super.dispose();
  }

  /// Performs a smooth, animated camera glide to a target [destCenter] and [destZoom].
  void _animatedMapMove(LatLng destCenter, double destZoom) {
    // Stop & dispose any existing camera move animation to prevent concurrent fighting
    _moveController?.stop();
    _moveController?.dispose();
    _moveController = null;

    try {
      final camera = _mapController.camera;
      final double startLat = camera.center.latitude;
      final double startLng = camera.center.longitude;
      final double startZoom = camera.zoom;

      final controller = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      _moveController = controller;

      final Animation<double> curve = CurvedAnimation(
        parent: controller,
        curve: Curves.fastOutSlowIn,
      );

      controller.addListener(() {
        if (_moveController != controller) return;
        _mapController.move(
          LatLng(
            startLat + (destCenter.latitude - startLat) * curve.value,
            startLng + (destCenter.longitude - startLng) * curve.value,
          ),
          startZoom + (destZoom - startZoom) * curve.value,
        );
      });

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          if (_moveController == controller) {
            _moveController = null;
          }
          controller.dispose();
        }
      });

      controller.forward();
    } catch (e) {
      _moveController = null;
    }
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

  bool _shouldLoadHighlightsFor(LatLng location) {
    final DateTime now = DateTime.now();
    final LatLng? previousLocation = _lastHighlightsLocation;
    final DateTime? previousLoad = _lastHighlightsLoadedAt;

    if (previousLocation == null || previousLoad == null) {
      _lastHighlightsLocation = location;
      _lastHighlightsLoadedAt = now;
      return true;
    }

    final bool movedEnough = _distance(previousLocation, location) >= 120;
    final bool staleEnough =
        now.difference(previousLoad) >= const Duration(seconds: 30);
    if (!movedEnough && !staleEnough) return false;

    _lastHighlightsLocation = location;
    _lastHighlightsLoadedAt = now;
    return true;
  }

  List<Widget> _buildTileLayers(BuildContext context) {
    final bool useRetina = MediaQuery.devicePixelRatioOf(context) > 1.5;

    if (!_cacheReady) {
      //defensive fallback
      return [
        TileLayer(
          urlTemplate: MapConfig.cartoLightUrl,
          fallbackUrl:
              'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: MapConfig.subdomains,
          userAgentPackageName: MapConfig.userAgentPackageName,
          tileProvider: NetworkTileProvider(
            headers: Map.of(MapConfig.tileHeaders),
          ),
          retinaMode: useRetina,
          keepBuffer: 3,
          panBuffer: 2,
          tileDisplay: const TileDisplay.fadeIn(
            duration: Duration(milliseconds: 120),
          ),
        ),
      ];
    }

    // One TileLayer per zoom band instead of one layer for the whole
    // zoom range — each is only active within its own [minZoom, maxZoom],
    // and is backed by that band's own sharded cache store (see
    // MapCacheManager). This keeps each Hive box's key index small and
    // lets bands be pruned on independent budgets.
    return [
      for (final TileZoomBand band in TileZoomBand.values)
        TileLayer(
          urlTemplate: MapConfig.cartoLightUrl,
          fallbackUrl:
              'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: MapConfig.subdomains,
          userAgentPackageName: MapConfig.userAgentPackageName,
          retinaMode: useRetina,
          minZoom: band.minZoom.toDouble(),
          maxZoom: band.maxZoom.toDouble(),

          // Retain more off-screen tiles (incl. from a recent zoom
          // level) and preload a wider margin around the viewport —
          // removes frequent white-screen flashes on pan/zoom.
          keepBuffer: 3,
          panBuffer: 2,
          tileDisplay: const TileDisplay.fadeIn(
            duration: Duration(milliseconds: 120),
          ),
          tileProvider: CachedTileProvider(
            dio: _tileDios[band],
            store: MapCacheManager.instance.storeFor(band),
            maxStale: band.maxStale,
            hitCacheOnErrorExcept: const [],
            cachePolicy: CachePolicy.forceCache,
            interceptors: const [],
            keyBuilder: CacheOptions.defaultCacheKeyBuilder,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double controlsTopOffset = statusBarHeight + 12 + 54 + 14;

    return BlocListener<MapCubit, MapState>(
      listenWhen: (previous, current) {
        final bool animateRequested =
            current.animateToState &&
            (current.center != previous.center ||
                current.zoom != previous.zoom ||
                !previous.animateToState);
        final bool errorBroadcast = current.errorSignal != null;
        final bool locationUpdated =
            current.userLocation != previous.userLocation;
        return animateRequested || errorBroadcast || locationUpdated;
      },
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
        if (state.userLocation != null &&
            _shouldLoadHighlightsFor(state.userLocation!)) {
          context.read<FacilityBloc>().add(
            LoadHighlights(
              userLat: state.userLocation!.latitude,
              userLng: state.userLocation!.longitude,
            ),
          );
        }
      },
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: MapConfig.yaoundeLatLng,
              initialZoom: MapConfig.initialZoom,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              keepAlive: true,
              backgroundColor: const Color(0xFFF4F2ED),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  context.read<MapCubit>().updateViewport(
                    camera.center,
                    camera.zoom,
                  );
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd) {
                  _preFetchService?.schedule(
                    zoom: event.camera.zoom,
                    visibleBounds: event.camera.visibleBounds,
                    useRetina: MediaQuery.devicePixelRatioOf(context) > 1.5,
                  );
                }
              },
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedFacility = null;
                });
                _headerSearchKey.currentState?.clearSearch(notify: false);
                context.read<MapCubit>().returnToIdle();
                context.read<FacilityBloc>().add(ClearSearch());
              },
            ),
            children: [
              ..._buildTileLayers(context),
              const SmoothUserLocationLayer(),
              BlocBuilder<MapCubit, MapState>(
                buildWhen: (prev, curr) =>
                    prev.interactionState != curr.interactionState,
                builder: (context, mapState) {
                  return BlocBuilder<FacilityBloc, FacilityState>(
                    buildWhen: (prev, curr) =>
                        prev.facilities != curr.facilities,
                    builder: (context, facilityState) {
                      final allFacilities = facilityState.facilities.toList();
                      if (_selectedFacility != null &&
                          !allFacilities.any(
                            (f) =>
                                f.facilityId == _selectedFacility!.facilityId,
                          )) {
                        allFacilities.add(_selectedFacility!);
                      }

                      if (allFacilities.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final selectedFacilityId =
                          mapState.interactionState is MapPinSelected
                          ? (mapState.interactionState as MapPinSelected)
                                .facilityId
                          : mapState.interactionState is MapDetailSheet
                          ? (mapState.interactionState as MapDetailSheet)
                                .facilityId
                          : null;

                      final markers = allFacilities.map((facility) {
                        return Marker(
                          point: LatLng(facility.latitude, facility.longitude),
                          width: 34,
                          height: 41,
                          alignment: Alignment.bottomCenter,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFacility = facility;
                              });
                              _animatedMapMove(
                                LatLng(facility.latitude, facility.longitude),
                                15.5,
                              );
                              context.read<MapCubit>().selectPin(
                                facility.facilityId,
                              );
                            },
                            child: FacilityMapMarker(
                              type: facility.type,
                              isSelected:
                                  facility.facilityId == selectedFacilityId,
                            ),
                          ),
                        );
                      }).toList();

                      return MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 45,
                          size: const Size(48, 48),
                          alignment: Alignment.center,
                          markers: markers,
                          animationsOptions: const AnimationsOptions(
                            zoom: Duration(milliseconds: 320),
                            fitBound: Duration(milliseconds: 420),
                            centerMarker: Duration(milliseconds: 320),
                            spiderfy: Duration(milliseconds: 320),
                            fadeInCurve: Curves.easeOutCubic,
                            fadeOutCurve: Curves.easeInCubic,
                            clusterExpandCurve: Curves.easeOutCubic,
                            clusterCollapseCurve: Curves.easeInCubic,
                            fitBoundCurves: Curves.fastOutSlowIn,
                            centerMarkerCurves: Curves.fastOutSlowIn,
                            spiderifyCurve: Curves.fastOutSlowIn,
                          ),
                          builder: (context, clusterMarkers) =>
                              FacilityClusterMarker(
                                count: clusterMarkers.length,
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          // Floating Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HeaderSearch(
              key: _headerSearchKey,
              onFacilitySelected: (facility) {
                setState(() {
                  _selectedFacility = facility;
                });
                _animatedMapMove(
                  LatLng(facility.latitude, facility.longitude),
                  15.5,
                );
                context.read<MapCubit>().selectPin(facility.facilityId);
              },
              onClear: () {
                setState(() {
                  _selectedFacility = null;
                });
                context.read<MapCubit>().returnToIdle();
                context.read<FacilityBloc>().add(ClearSearch());
              },
            ),
          ),
          // Map Controls Panel
          Positioned(
            right: 20,
            top: controlsTopOffset,
            child: const MapControls(),
          ),
          // Overlays (Carousel card)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 0,
            right: 0,
            child: BlocBuilder<MapCubit, MapState>(
              buildWhen: (prev, curr) =>
                  prev.interactionState != curr.interactionState ||
                  (prev.userLocation == null) != (curr.userLocation == null),
              builder: (context, state) => _buildBottomOverlay(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOverlay(BuildContext context, MapState state) {
    final interaction = state.interactionState;
    if (state.userLocation == null) return const SizedBox.shrink();

    if (interaction is MapPinSelected || interaction is MapDetailSheet) {
      final facilityId = interaction is MapPinSelected
          ? interaction.facilityId
          : (interaction as MapDetailSheet).facilityId;
      FacilityModel? facility = _selectedFacility;
      if (facility == null || facility.facilityId != facilityId) {
        try {
          final facilities = context.read<FacilityBloc>().state.facilities;
          facility = facilities.firstWhere((f) => f.facilityId == facilityId);
        } catch (_) {
          facility = _selectedFacility;
        }
      }

      if (facility != null) {
        return SelectedFacilityCard(
          facility: facility,
          userLat: state.userLocation?.latitude,
          userLng: state.userLocation?.longitude,
          onCardTap: (f) async {
            context.read<FacilityBloc>().add(
              LoadFacilityDetail(f.facilityId),
            );
            context.read<MapCubit>().expandSheet(f.facilityId);
            await FacilityExpandedSheet.show(
              context,
              f.facilityId,
              userLat: state.userLocation?.latitude,
              userLng: state.userLocation?.longitude,
            );
            if (context.mounted) {
              context.read<MapCubit>().selectPin(f.facilityId);
            }
          },
        );
      }
    }

    return Visibility(
      visible: interaction is MapIdle,
      maintainState: true,
      child: HighlightsCarousel(
        userLat: state.userLocation!.latitude,
        userLng: state.userLocation!.longitude,
        onCardTap: (facility) async {
          setState(() {
            _selectedFacility = facility;
          });
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
            context.read<MapCubit>().selectPin(facility.facilityId);
          }
        },
      ),
    );
  }
}
