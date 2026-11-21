import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:yalla_5roga/core/monitoring/performance_service.dart';
import 'package:yalla_5roga/core/network/diagnostics/mobile_telemetry.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_scope.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

class RequestDiagnosticsInterceptor extends Interceptor {
  RequestDiagnosticsInterceptor({
    RequestDiagnostics? diagnostics,
    this.currentUserId,
    this.telemetry,
    this.firebase = true,
  }) : _diagnostics = diagnostics ?? RequestDiagnostics.instance;

  final RequestDiagnostics _diagnostics;
  final String? Function()? currentUserId;
  final MobileTelemetry? telemetry;
  final bool firebase;
  final _random = Random.secure();
  final _recent = <int, _Repeats>{};
  final _clock = Stopwatch()..start();

  static const _attempt = 'request_diagnostics_attempt';
  static const _operation = 'request_diagnostics_operation';
  static const _window = int.fromEnvironment(
    'API_DUPLICATE_WINDOW_MS',
    defaultValue: 2000,
  );
  static const _triggerHeader = 'X-Request-Trigger';
  static final _timing = RegExp(r'(?:^|,\s*)app;dur=(\d+(?:\.\d+)?)(?:[,;]|$)');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra.remove(_attempt);
    options.headers['X-Client-Source'] = 'flutter';
    final id = _uuid();
    final operation = options.extra.putIfAbsent(_operation, () => id) as String;
    options.headers['X-Request-ID'] = id;
    options.headers['X-Correlation-ID'] = operation;
    final scope = RequestScope.current;
    final retry = options.extra[authRetriedKey] == true ? 1 : 0;
    final trigger = retry > 0 ? 'retry' : scope?.trigger ?? 'unknown';
    options.headers[_triggerHeader] = trigger;
    if (options.extra[MobileTelemetry.ignoredKey] == true) {
      handler.next(options);
      return;
    }

    final endpoint = RequestDiagnostics.normalizeEndpoint(options.uri.path);
    final repeated = RequestDiagnostics.enabled
        ? _repetition(options, trigger, endpoint)
        : null;
    final attempt = _Attempt(
      id,
      operation,
      Stopwatch()..start(),
      DateTime.now(),
      scope,
      trigger,
      endpoint,
      retry,
      repeated,
    );
    options.extra[_attempt] = attempt;
    if (firebase) {
      unawaited(_startFirebase(attempt, options.uri, options.method));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      _finish(response.requestOptions, response: response);
    } catch (_) {
      // Diagnostics must leave the response available to the caller.
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      _finish(err.requestOptions, response: err.response, error: err.type);
    } catch (_) {
      // Diagnostics must leave the original error available to the caller.
    }
    handler.next(err);
  }

  void _finish(
    RequestOptions options, {
    Response? response,
    DioExceptionType? error,
  }) {
    final attempt = options.extra.remove(_attempt);
    if (attempt is! _Attempt) return;
    attempt.clock.stop();
    attempt.repeated?.row.active--;
    final elapsed = attempt.clock.elapsedMicroseconds / 1000;
    final headers = response?.headers;
    final timing = _header(headers, 'server-timing');
    final server = timing == null
        ? null
        : double.tryParse(_timing.firstMatch(timing)?.group(1) ?? '');
    final bytes = int.tryParse(_header(headers, 'content-length') ?? '');
    final cache = _header(headers, 'x-cache-status')?.toLowerCase();
    final route = _header(headers, 'x-route-template');
    final endpoint = route != null && route.startsWith('/api/')
        ? RequestDiagnostics.normalizeEndpoint(route)
        : attempt.endpoint;
    final status = response?.statusCode;
    final outcome = cache == 'hit'
        ? RequestOutcome.cache
        : RequestOutcome.network;
    final account = currentUserId?.call();
    final expected = options.extra[expectedUserIdKey];
    final sameAccount = expected == null || expected == account;
    if (sameAccount && route != null && route == endpoint) {
      telemetry?.record(
        endpoint: endpoint,
        method: options.method,
        status: status ?? 0,
        clientMs: elapsed,
        serverMs: server,
        cache: cache,
      );
    }
    _diagnostics.record(
      RequestDiagnosticEntry(
        method: options.method,
        endpoint: endpoint,
        normalizedEndpoint: endpoint,
        timestamp: DateTime.now(),
        startedAt: attempt.startedAt,
        durationMs: elapsed.round(),
        outcome: outcome,
        statusCode: status,
        feature: attempt.scope?.feature ?? _feature(endpoint),
        source: attempt.scope?.origin ?? 'ApiClient',
        operation: attempt.scope?.operation,
        requestId: _requestId(_header(headers, 'x-request-id')) ?? attempt.id,
        operationId: attempt.operation,
        trigger: attempt.trigger,
        serverMs: server,
        overheadMs: server != null && elapsed >= server
            ? elapsed - server
            : null,
        responseBytes: bytes,
        cacheStatus: cache,
        retry: attempt.retry,
        error: error != null,
        errorKind: error?.name,
        duplicateCount: attempt.repeated?.duplicateCount,
        concurrent: attempt.repeated?.concurrent,
      ),
    );
    unawaited(_finishFirebase(attempt, status, bytes));
  }

  static String? _header(Headers? headers, String name) {
    final values = headers?[name];
    return values == null || values.isEmpty ? null : values.join(', ');
  }

  static String? _requestId(String? value) =>
      value != null &&
          RegExp(
            r'^(?:req_)?[a-f0-9-]{36}$',
            caseSensitive: false,
          ).hasMatch(value)
      ? value
      : null;

  static String? _feature(String endpoint) {
    final parts = endpoint.split('/');
    return parts.length > 2 && parts[1] == 'api' ? parts[2] : null;
  }

  Future<void> _startFirebase(_Attempt attempt, Uri uri, String method) async {
    try {
      final normalized = attempt.endpoint.replaceAll(':', '_');
      final safeUrl = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: normalized,
      );
      final firebaseMethod = switch (method) {
        'POST' => HttpMethod.Post,
        'PATCH' => HttpMethod.Patch,
        'PUT' => HttpMethod.Put,
        'DELETE' => HttpMethod.Delete,
        'HEAD' => HttpMethod.Head,
        'OPTIONS' => HttpMethod.Options,
        _ => HttpMethod.Get,
      };
      final metric = PerformanceService.instance.newHttpMetric(
        safeUrl.toString(),
        firebaseMethod,
      );
      if (metric == null) return;
      attempt.firebaseMetric = metric;
      attempt.firebaseStarted = metric.start();
      await attempt.firebaseStarted;
    } catch (_) {
      attempt.firebaseMetric = null;
    }
  }

  Future<void> _finishFirebase(
    _Attempt attempt,
    int? status,
    int? bytes,
  ) async {
    final metric = attempt.firebaseMetric;
    if (metric == null) return;
    try {
      await attempt.firebaseStarted;
      if (status != null) metric.httpResponseCode = status;
      if (bytes != null && bytes >= 0) metric.responsePayloadSize = bytes;
      await metric.stop();
    } catch (_) {
      // Firebase monitoring must not affect the outcome of the request.
    }
  }

  _Duplicate? _repetition(
    RequestOptions options,
    String trigger,
    String endpoint,
  ) {
    if (const {
      'retry',
      'manual_refresh',
      'pagination',
      'search',
      'viewport_changed',
    }.contains(trigger)) {
      return null;
    }
    final isRead = options.method == 'GET' || options.method == 'HEAD';
    if (!isRead && endpoint != '/api/users/sync') return null;
    final sortedQuery = options.uri.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final body = options.data;
    final fingerprint = !isRead && body is Map
        ? Object.hash(body['phone'], body['phoneVerificationToken'])
        : 0;
    final key = Object.hash(
      currentUserId?.call(),
      options.method,
      options.uri.path,
      Object.hashAll(
        sortedQuery.map(
          (entry) => Object.hash(entry.key, Object.hashAll(entry.value)),
        ),
      ),
      trigger,
      fingerprint,
    );
    final now = _clock.elapsedMilliseconds;
    var row = _recent[key];
    if (row == null || (row.active == 0 && now - row.started >= _window)) {
      _recent.remove(key);
      if (_recent.length >= 512) _recent.remove(_recent.keys.first);
      row = _Repeats(now);
      _recent[key] = row;
    }
    row.count++;
    row.active++;
    final suspicious =
        row.active == 2 || (row.count == 3 && now - row.started < _window);
    return _Duplicate(row, suspicious ? row.count : null, row.active);
  }

  String _uuid() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class _Attempt {
  _Attempt(
    this.id,
    this.operation,
    this.clock,
    this.startedAt,
    this.scope,
    this.trigger,
    this.endpoint,
    this.retry,
    this.repeated,
  );

  final String id;
  final String operation;
  final Stopwatch clock;
  final DateTime startedAt;
  final RequestScope? scope;
  final String trigger;
  final String endpoint;
  final int retry;
  final _Duplicate? repeated;
  HttpMetric? firebaseMetric;
  Future<void>? firebaseStarted;
}

class _Repeats {
  _Repeats(this.started);
  final int started;
  int count = 0;
  int active = 0;
}

class _Duplicate {
  _Duplicate(this.row, this.duplicateCount, this.concurrent);
  final _Repeats row;
  final int? duplicateCount;
  final int concurrent;
}
