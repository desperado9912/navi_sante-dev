import 'dart:async';
import 'dart:io';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages Hive- Map tile caching for the NaviSante map.
///
/// Responsibilities:
///   - Initialises HiveCacheStore inside the OS temporary directory so the
///     OS can reclaim storage automatically when the device runs low.
///   - Enforces a 500 MB storage cap.
///   - Removes tiles older than 30 days on startup and every 24 hours.

class MapCacheManager {
  // Cache folder disk size, duration, hive box name constants.
  static const int maxCacheSizeBytes = 524 * 1024 * 1024;
  static const Duration cacheTtl = Duration(days: 30);
  static const String _hiveBoxName = 'navisante_map_tiles';

  HiveCacheStore? _store;
  String? _cachePath;
  Timer? _cleanupTimer;

  CacheStore get store {
    assert(_store != null, 'Call initialize() before accessing store.');
    return _store!;
  }

  /// Initialises Hive in the device's OS temporary directory
  Future<HiveCacheStore> initialize() async {
    // Place cache in the OS temp folder.
    final tempDir = await getTemporaryDirectory();
    _cachePath = '${tempDir.path}/navisante_tile_cache';

    _store = HiveCacheStore(_cachePath!, hiveBoxName: _hiveBoxName);

    // Clean any stale tiles left from the previous session.
    await _cleanStaleEntries();
    // Enforce the 500 MB cap right after stale cleanup.
    await _enforceSizeLimit();

    // Schedule recurring cleanup every 24 hours.
    _cleanupTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      await _cleanStaleEntries();
      await _enforceSizeLimit();
    });

    debugPrint(
      '[MapCache] Raedy | path: $_cachePath'
      ' | max ${maxCacheSizeBytes ~/ (1024 * 1024)} MB'
      ' | TTL ${cacheTtl.inDays} days',
    );

    return _store!;
  }

  /// Cancels the cleanup timer and dispose the Hive box.
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _store?.close();
    _store = null;
  }

  /// Removes only entries whose maxStale duration has been exceeded.
  Future<void> _cleanStaleEntries() async {
    try {
      // staleOnly: true → only evicts tiles whose 30-day window has passed.
      await _store?.clean(staleOnly: true);
      debugPrint('[MapCache] Stale tile cleanup complete.');
    } catch (e) {
      debugPrint('[MapCache] Cleanup error (non-fatal): $e');
    }
  }

  /// Calculates the cache directory size to enforce 500 MB cap as Hive does not directly handle this.
  Future<void> _enforceSizeLimit() async {
    if (_cachePath == null) return;
    try {
      final int size = await _directorySizeBytes(_cachePath!);

      if (size <= maxCacheSizeBytes) return; // Within budget — nothing to do.

      final int sizeMb = size ~/ (1024 * 1024);
      debugPrint(
        '[MapCache] Cache is $sizeMb MB — over limit. Pruning stale entries...',
      );

      // Step 1: remove stale-only (already done in scheduler, but repeat
      // here because enforce is also called right after initialize()).
      await _store?.clean(staleOnly: true);

      final int sizeAfter = await _directorySizeBytes(_cachePath!);
      if (sizeAfter <= maxCacheSizeBytes) {
        debugPrint(
          '[MapCache] Pruned to ${sizeAfter ~/ (1024 * 1024)} MB — OK.',
        );
        return;
      }

      // Step 2: still over limit — full wipe.
      await _store?.clean();
      debugPrint(
        '[MapCache] Full wipe: cache exceeded ${maxCacheSizeBytes ~/ (1024 * 1024)} MB hard cap.',
      );
    } catch (e) {
      debugPrint('[MapCache] Size enforcement error (non-fatal): $e');
    }
  }

  /// Recursively sums the byte size of all files in [dirPath].
  Future<int> _directorySizeBytes(String dirPath) async {
    final dir = Directory(dirPath);
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
