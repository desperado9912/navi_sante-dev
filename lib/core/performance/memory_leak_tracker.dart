import 'package:flutter/foundation.dart';

/// A simple, lightweight memory leak tracker designed for development mode.
///
/// Logs when controllers, animations, change notifiers, or stream subscriptions
/// are created and disposed. This creates a clear lifecycle log, allowing developers
/// to quickly verify that allocations are cleanly released, resolving memory leaks
/// that cause sluggishness over time.
class MemoryLeakTracker {
  MemoryLeakTracker._();

  /// Logs the initialization of a stateful object.
  static void logInit(Object object) {
    if (kDebugMode) {
      debugPrint('♻️ [Lifecycle] INIT: ${object.runtimeType} (Hash: ${identityHashCode(object)})');
    }
  }

  /// Logs the disposal/cleanup of a stateful object.
  static void logDispose(Object object) {
    if (kDebugMode) {
      debugPrint('♻️ [Lifecycle] DISPOSE: ${object.runtimeType} (Hash: ${identityHashCode(object)})');
    }
  }
}
