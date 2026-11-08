import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';

/// Reuses an in-flight Future for identical request keys.
///
/// Failed futures are removed so callers can retry. Completed successes are
/// also removed after settle so the next call can refresh (caching lives in
/// [TtlCache] / [cachedRemote], not here).
class RequestDeduper {
  RequestDeduper({RequestDiagnostics? diagnostics})
    : _diagnostics = diagnostics ?? RequestDiagnostics.instance;

  final RequestDiagnostics _diagnostics;
  final Map<String, Future<dynamic>> _inFlight = {};

  int get inFlightCount => _inFlight.length;

  bool isInFlight(String key) => _inFlight.containsKey(key);

  /// Runs [run] once per [key] while a prior call is pending.
  Future<T> run<T>(
    String key,
    Future<T> Function() run, {
    String? feature,
    String? source,
    String? operation,
    String method = 'GET',
    String? endpoint,
  }) {
    final existing = _inFlight[key];
    if (existing != null) {
      if (kDebugMode) {
        _diagnostics.recordLocal(
          method: method,
          endpoint: endpoint ?? key,
          outcome: RequestOutcome.deduped,
          feature: feature,
          source: source,
          operation: operation,
        );
      }
      return existing.then((value) => value as T);
    }

    final future = run();
    _inFlight[key] = future;
    return future.whenComplete(() {
      _inFlight.remove(key);
    });
  }

  void clear() => _inFlight.clear();

  /// Stable key for method + path + sorted query.
  static String keyFor({
    required String method,
    required String path,
    Map<String, dynamic>? query,
  }) {
    final buffer = StringBuffer('${method.toUpperCase()} $path');
    if (query != null && query.isNotEmpty) {
      final keys = query.keys.toList()..sort();
      buffer.write('?');
      buffer.write(
        [
          for (final k in keys) '$k=${query[k]}',
        ].join('&'),
      );
    }
    return buffer.toString();
  }
}
