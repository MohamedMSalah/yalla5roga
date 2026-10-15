import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Custom traces + helpers for important app operations.
class PerformanceService {
  PerformanceService._();

  static final PerformanceService instance = PerformanceService._();

  FirebasePerformance get _performance => FirebasePerformance.instance;

  var _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    await _performance.setPerformanceCollectionEnabled(true);
    _ready = true;
  }

  /// Runs [action] inside a named custom trace. Errors propagate unchanged.
  Future<T> trace<T>(String name, Future<T> Function() action) async {
    if (!_ready) return action();

    final custom = _performance.newTrace(name);
    await custom.start();
    if (kDebugMode) debugPrint('[Performance] start $name');
    try {
      return await action();
    } finally {
      await custom.stop();
      if (kDebugMode) debugPrint('[Performance] stop $name');
    }
  }

  HttpMetric? newHttpMetric(String url, HttpMethod method) {
    if (!_ready) return null;
    return _performance.newHttpMetric(url, method);
  }
}
