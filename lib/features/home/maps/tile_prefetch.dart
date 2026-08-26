import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_map/flutter_map.dart';
import '../controller/map_cache_manager.dart';
import 'map_service.dart';

class _TileCoord {
  final int z;
  final int x;
  final int y;
  const _TileCoord(this.z, this.x, this.y);
}

/// Warms the tile cache for the area just outside the current viewport,
/// plus the zoom levels one step in/out, so panning and pinch-zooming
/// land on an already-cached tile instead of triggering a fresh network
/// fetch — that fetch is what shows up as a white-screen flash.
///
/// Runs with a small bounded-concurrency pool so background prefetching
/// never competes hard enough with foreground tile requests to slow the
/// device down or burn through the data/battery budget. Every prefetched
/// tile is written with [CachePriority.low], so it's always the first
/// thing evicted if storage pressure hits — a real, user-requested tile
/// never loses its cached copy to a prefetch guess.
class TilePrefetchService {
  TilePrefetchService({this.maxConcurrentRequests = 4}) {
    for (final TileZoomBand band in TileZoomBand.values) {
      final Dio dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: Map.of(MapConfig.tileHeaders),
        ),
      );
      dio.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(
            store: MapCacheManager.instance.storeFor(band),
            policy: CachePolicy.request,
            maxStale: band.maxStale,
            priority: CachePriority.low,
          ),
        ),
      );
      _dioByBand[band] = dio;
    }
  }

  /// Beyond this, a single batch is almost certainly a mis-fire (e.g. an
  /// extreme zoom-out) rather than a genuine "warm the edges" request —
  /// skip it rather than flooding the device with requests.
  static const int _maxTilesPerBatch = 60;

  final int maxConcurrentRequests;
  final Map<TileZoomBand, Dio> _dioByBand = {};

  Timer? _debounce;
  CancelToken? _activeBatchCancelToken;

  /// Schedules a prefetch pass shortly after the camera settles. Safe to
  /// call on every camera-position event — repeated calls just push the
  /// debounce back, so a continuous pan/animation only triggers one batch
  /// once it actually stops moving.
  void schedule({
    required double zoom,
    required LatLngBounds visibleBounds,
    required bool useRetina,
  }) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(
        _runBatch(
          zoom: zoom,
          visibleBounds: visibleBounds,
          useRetina: useRetina,
        ),
      );
    });
  }

  void dispose() {
    _debounce?.cancel();
    _activeBatchCancelToken?.cancel('disposed');
    for (final Dio dio in _dioByBand.values) {
      dio.close(force: true);
    }
  }

  Future<void> _runBatch({
    required double zoom,
    required LatLngBounds visibleBounds,
    required bool useRetina,
  }) async {
    _activeBatchCancelToken?.cancel('superseded by a newer viewport');
    final CancelToken cancelToken = CancelToken();
    _activeBatchCancelToken = cancelToken;

    final int baseZoom = zoom.round().clamp(
      MapConfig.minZoom.round(),
      MapConfig.maxZoom.round(),
    );

    final List<_TileCoord> targets = [
      // One extra ring beyond the visible edge, at the current zoom —
      // complements TileLayer.panBuffer for corner/diagonal tiles it
      // doesn't cover.
      ..._tilesForBounds(visibleBounds, baseZoom, ringPadding: 1),
      // One step in (pinch-zoom-in) — the single most common gesture.
      if (baseZoom < MapConfig.maxZoom.round())
        ..._tilesForBounds(visibleBounds, baseZoom + 1, ringPadding: 0),
      // One step out (pinch-zoom-out).
      if (baseZoom > MapConfig.minZoom.round())
        ..._tilesForBounds(visibleBounds, baseZoom - 1, ringPadding: 0),
    ];

    if (targets.isEmpty || targets.length > _maxTilesPerBatch) return;

    await _runWithBoundedConcurrency(targets, cancelToken, useRetina);
  }

  Future<void> _runWithBoundedConcurrency(
    List<_TileCoord> targets,
    CancelToken cancelToken,
    bool useRetina,
  ) async {
    int nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < targets.length) {
        if (cancelToken.isCancelled) return;
        final _TileCoord tile = targets[nextIndex++];
        await _fetchAndCache(tile, useRetina, cancelToken);
      }
    }

    final int workerCount = math.min(maxConcurrentRequests, targets.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  Future<void> _fetchAndCache(
    _TileCoord tile,
    bool useRetina,
    CancelToken cancelToken,
  ) async {
    final TileZoomBand band = TileZoomBand.forZoom(tile.z);
    final Dio? dio = _dioByBand[band];
    if (dio == null) return;

    final String url = _buildTileUrl(tile, useRetina);
    try {
      await dio.get<List<int>>(
        url,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (_) {
      // Best-effort background work. A failed prefetch just means that
      // tile falls back to a normal on-demand fetch later — never
      // surface this to the user.
    }
  }

  String _buildTileUrl(_TileCoord tile, bool useRetina) {
    final String retinaSuffix = useRetina ? '@2x' : '';
    return MapConfig.cartoLightUrl
        .replaceAll('{s}', MapConfig.tileSubdomain)
        .replaceAll('{z}', '${tile.z}')
        .replaceAll('{x}', '${tile.x}')
        .replaceAll('{y}', '${tile.y}')
        .replaceAll('{r}', retinaSuffix);
  }

  List<_TileCoord> _tilesForBounds(
    LatLngBounds bounds,
    int zoom, {
    required int ringPadding,
  }) {
    final int maxTileIndex = (1 << zoom) - 1;
    final int minX = (_lonToTileX(bounds.west, zoom) - ringPadding).clamp(
      0,
      maxTileIndex,
    );
    final int maxX = (_lonToTileX(bounds.east, zoom) + ringPadding).clamp(
      0,
      maxTileIndex,
    );
    final int minY = (_latToTileY(bounds.north, zoom) - ringPadding).clamp(
      0,
      maxTileIndex,
    );
    final int maxY = (_latToTileY(bounds.south, zoom) + ringPadding).clamp(
      0,
      maxTileIndex,
    );

    final List<_TileCoord> tiles = [];
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        tiles.add(_TileCoord(zoom, x, y));
      }
    }
    return tiles;
  }

  int _lonToTileX(double lon, int z) =>
      ((lon + 180.0) / 360.0 * (1 << z)).floor();

  int _latToTileY(double lat, int z) {
    final double latRad = lat * math.pi / 180.0;
    return ((1.0 -
                math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            (1 << z))
        .floor();
  }
}
