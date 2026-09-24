import 'dart:async';
import 'dart:io';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages Hive- Map tile caching for the NaviSante map.
///
/// Responsibilities:
///   - Initialises HiveCacheStore under [getApplicationSupportDirectory].
///   - Storage is split into three [TileZoomBand] shards, each wrapped
///     with a small in-memory layer via the [BackupCacheStore],
///     so tiles seen earlier re-render instantly.
///   - OS can purge device storage layer under pressure which would silently
///     wipe all cahed tiles and reproduce a slow first load at random.
///   - Three band storage; overview 80mb, district 150, street 270. capped at 500mb

// Separate tile storage for each zoom band
// Each band gets its own box (smaller key index → faster to open),
/// its own eviction budget, and its own retention window
enum TileZoomBand {
  overview(
    minZoom: 3,
    maxZoom: 11,
    maxCacheBytes: 80 * 1024 * 1024,
    maxStale: Duration(days: 20),
    memCacheBytes: 3 * 1024 * 1024,
  ),
  district(
    minZoom: 12,
    maxZoom: 15,
    maxCacheBytes: 150 * 1024 * 1024,
    maxStale: Duration(days: 30),
    memCacheBytes: 5 * 1024 * 1024,
  ),
  street(
    minZoom: 16,
    maxZoom: 19,
    maxCacheBytes: 270 * 1024 * 1024,
    maxStale: Duration(days: 30),
    memCacheBytes: 6 * 1024 * 1024,
  );

  const TileZoomBand({
    required this.minZoom,
    required this.maxZoom,
    required this.maxCacheBytes,
    required this.maxStale,
    required this.memCacheBytes,
  });

  final int minZoom;
  final int maxZoom;
  final int maxCacheBytes;
  final Duration maxStale;
  final int memCacheBytes;

  static TileZoomBand forZoom(int zoom) {
    for (final band in TileZoomBand.values) {
      if (zoom >= band.minZoom && zoom <= band.maxZoom) return band;
    }
    return zoom < TileZoomBand.overview.minZoom
        ? TileZoomBand.overview
        : TileZoomBand.street;
  }
}

class MapCacheManager {
  MapCacheManager._internal();
  static final MapCacheManager instance = MapCacheManager._internal();

  final Map<TileZoomBand, CacheStore> _stores = {};
  Completer<void> _readyCompleter = Completer<void>();
  Future<void>? _initializationFuture;
  bool _ready = false;
  String? _cachePath;
  Timer? _maintenanceTimer;

  Future<void> get whenReady => _readyCompleter.future;
  bool get isReady => _ready;

  CacheStore storeFor(TileZoomBand band) {
    final CacheStore? store = _stores[band];
    assert(
      store != null,
      'MapCacheManager.storeFor() called before initialize()/whenReady completed.',
    );
    return store!;
  }

  // Opens all band hive boxes.
  Future<void> initialize() async {
    if (_ready) return;
    final Future<void>? inFlight = _initializationFuture;
    if (inFlight != null) return inFlight;

    _initializationFuture = _initializeStores();
    return _initializationFuture;
  }

  Future<void> _initializeStores() async {
    try {
      final Directory baseDir = await getApplicationSupportDirectory();
      _cachePath = '${baseDir.path}/navisante_tile_cache';

      for (final band in TileZoomBand.values) {
        final String bandPath = '$_cachePath/${band.name}';
        final String boxName = 'navisante_map_tiles_${band.name}';

        // Proactively test for Hive box corruption.
        // A corrupted box will block tile reads and cause long delays.
        try {
          final box = await Hive.openBox(boxName, path: bandPath);
          await box.close();
        } catch (e) {
          debugPrint('[MapCache] Detected corrupted Hive box for ${band.name}. Wiping... Error: $e');
          final dir = Directory(bandPath);
          try {
            if (await dir.exists()) {
              await dir.delete(recursive: true);
            }
          } catch (deleteError) {
            debugPrint('[MapCache] Failed to delete corrupted directory (ignoring): $deleteError');
          }
        }

        final HiveCacheStore hiveStore = HiveCacheStore(
          bandPath,
          hiveBoxName: boxName,
        );
        _stores[band] = BackupCacheStore(
          primary: MemCacheStore(maxSize: band.memCacheBytes),
          secondary: hiveStore,
        );
      }

      _ready = true;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      debugPrint(
        '[MapCache] Ready | path: $_cachePath'
        ' | bands: ${TileZoomBand.values.map((b) => b.name).join(', ')}',
      );

      // Maintenance timer.
      // Runs a detached hive cleaner on init and after the recurring time period.
      unawaited(_runMaintenance());
      _maintenanceTimer?.cancel();
      _maintenanceTimer = Timer.periodic(
        const Duration(hours: 48),
        (_) => unawaited(_runMaintenance()),
      );
    } catch (e, stackTrace) {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(e, stackTrace);
      }
      _readyCompleter = Completer<void>();
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = null;
    for (final CacheStore store in _stores.values) {
      await store.close();
    }
    _stores.clear();
    _ready = false;
    _initializationFuture = null;
    if (_readyCompleter.isCompleted) {
      _readyCompleter = Completer<void>();
    }
  }

  Future<void> _runMaintenance() async {
    for (final TileZoomBand band in TileZoomBand.values) {
      final CacheStore? store = _stores[band];
      if (store == null) continue;
      try {
        await store.clean(staleOnly: true);
      } catch (e) {
        debugPrint(
          '[MapCache] Stale cleanup error for ${band.name} (non-fatal): $e',
        );
      }
      await _enforceBandSizeLimit(band);
    }
  }

  Future<void> _enforceBandSizeLimit(TileZoomBand band) async {
    if (_cachePath == null) return;

    final String bandPath = '$_cachePath/${band.name}';

    try {
      final int size = await _directorySizeBytes(bandPath);
      if (size <= band.maxCacheBytes) return;

      debugPrint(
        '[MapCache] ${band.name} is ${size ~/ (1024 * 1024)} MB'
        ' — over ${band.maxCacheBytes ~/ (1024 * 1024)} MB cap. Pruning...',
      );

      // Evict prefetched-but-never-viewed tiles first
      await _stores[band]?.clean(priorityOrBelow: CachePriority.low);

      final int sizeAfter = await _directorySizeBytes(bandPath);
      if (sizeAfter > band.maxCacheBytes) {
        // Still over cap — wipe this band only; other bands are untouched.
        await _stores[band]?.clean();
        debugPrint(
          '[MapCache] Full wipe of ${band.name}: still over cap after low-priority prune.',
        );
      }
    } catch (e) {
      debugPrint(
        '[MapCache] Size enforcement error for ${band.name} (non-fatal): $e',
      );
    }
  }

  Future<int> _directorySizeBytes(String dirPath) async {
    final Directory dir = Directory(dirPath);
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
