import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';

/// Debug-only Dio interceptor that feeds [RequestDiagnostics].
///
/// Never logs Authorization headers, tokens, or request/response bodies.
class RequestDiagnosticsInterceptor extends Interceptor {
  RequestDiagnosticsInterceptor({RequestDiagnostics? diagnostics})
    : _diagnostics = diagnostics ?? RequestDiagnostics.instance;

  final RequestDiagnostics _diagnostics;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra[RequestDiagKeys.startedAt] = DateTime.now();
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      _record(
        options: response.requestOptions,
        statusCode: response.statusCode,
        error: false,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _record(
        options: err.requestOptions,
        statusCode: err.response?.statusCode,
        error: true,
      );
    }
    handler.next(err);
  }

  void _record({
    required RequestOptions options,
    required int? statusCode,
    required bool error,
  }) {
    final started = options.extra[RequestDiagKeys.startedAt];
    final now = DateTime.now();
    final durationMs = started is DateTime
        ? now.difference(started).inMilliseconds
        : 0;

    final outcomeRaw = options.extra[RequestDiagKeys.outcome];
    final outcome = switch (outcomeRaw) {
      'cache' => RequestOutcome.cache,
      'deduped' => RequestOutcome.deduped,
      _ => RequestOutcome.network,
    };

    final path = options.uri.path.isNotEmpty
        ? options.uri.path
        : options.path;

    _diagnostics.record(
      RequestDiagnosticEntry(
        method: options.method,
        endpoint: path,
        normalizedEndpoint: RequestDiagnostics.normalizeEndpoint(path),
        timestamp: now,
        durationMs: durationMs,
        outcome: outcome,
        statusCode: statusCode,
        feature: options.extra[RequestDiagKeys.feature] as String?,
        source: options.extra[RequestDiagKeys.source] as String?,
        operation: options.extra[RequestDiagKeys.operation] as String?,
        error: error,
      ),
    );
  }
}
