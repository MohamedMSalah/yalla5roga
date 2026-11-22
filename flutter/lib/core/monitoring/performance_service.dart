import 'package:firebase_performance/firebase_performance.dart';

/// Custom traces + helpers for important app operations.
class PerformanceService {
  PerformanceService._();

  static final PerformanceService instance = PerformanceService._();

  FirebasePerformance get _performance => FirebasePerformance.instance;

  var _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    const collect = bool.fromEnvironment(
      'FIREBASE_TELEMETRY_ENABLED',
      defaultValue: true,
    );
    await _performance.setPerformanceCollectionEnabled(collect);
    _ready = collect;
  }

  /// Runs [action] inside a named custom trace. Errors propagate unchanged.
  Future<T> trace<T>(String name, Future<T> Function() action) async {
    if (!_ready) return action();

    Trace? custom;
    try {
      custom = _performance.newTrace(name);
      await custom.start();
    } catch (_) {
      return action();
    }
    try {
      return await action();
    } finally {
      try {
        await custom.stop();
      } catch (_) {
        // A completed action still has its original outcome.
      }
    }
  }

  HttpMetric? newHttpMetric(String url, HttpMethod method) {
    if (!_ready) return null;
    return _performance.newHttpMetric(url, method);
  }
}
