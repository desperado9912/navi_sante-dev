import 'package:flutter/foundation.dart';

/// A performance utility to run expensive CPU or high-latency operations
/// off the main UI thread using Flutter's compute function (which wraps Dart isolates).
class IsolateRunner {
  IsolateRunner._();
  
  static Future<R> run<M, R>(ComputeCallback<M, R> callback, M message) async {
    return await compute(callback, message);
  }
}
