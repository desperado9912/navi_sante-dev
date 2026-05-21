import 'package:flutter/foundation.dart';

/// A performance utility to run expensive CPU or high-latency operations
/// off the main UI thread using Flutter's compute function (which wraps Dart isolates).
///
/// According to Apple Energy & Performance guidelines and Android Performance docs,
/// heavy computation or blocking network operations (such as DNS/Socket lookups)
/// should always be run off the main thread to prevent UI frame-drops, keeping
/// the frame rate consistent at 60-120 FPS.
class IsolateRunner {
  IsolateRunner._();
  
  static Future<R> run<M, R>(ComputeCallback<M, R> callback, M message) async {
    return await compute(callback, message);
  }
}
