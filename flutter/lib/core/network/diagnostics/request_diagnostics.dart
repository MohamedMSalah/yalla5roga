import 'package:flutter/foundation.dart';

/// Outcome of a recorded API attempt (debug diagnostics only).
enum RequestOutcome { network, cache, deduped }

/// One API attempt captured by [RequestDiagnostics] (no tokens/bodies).
class RequestDiagnosticEntry {
  const RequestDiagnosticEntry({
    required this.method,
    required this.endpoint,
    required this.normalizedEndpoint,
    required this.timestamp,
    required this.durationMs,
    required this.outcome,
    this.statusCode,
    this.feature,
    this.source,
    this.operation,
    this.error = false,
  });

  final String method;
  final String endpoint;
  final String normalizedEndpoint;
  final DateTime timestamp;
  final int durationMs;
  final RequestOutcome outcome;
  final int? statusCode;
  final String? feature;
  final String? source;
  final String? operation;
  final bool error;

  String get identityKey => '${method.toUpperCase()} $normalizedEndpoint';
}

/// Development-only API request ring buffer and summary.
///
/// No-ops outside [kDebugMode]. Never stores Authorization headers or bodies.
class RequestDiagnostics {
  RequestDiagnostics._();

  static final RequestDiagnostics instance = RequestDiagnostics._();

  static const int maxEntries = 500;
  final List<RequestDiagnosticEntry> _entries = [];
  final Map<String, int> _countsByIdentity = {};
  final Map<String, int> _countsByFeature = {};
  var _cacheHits = 0;
  var _deduped = 0;
  var _network = 0;
  var _errors = 0;

  List<RequestDiagnosticEntry> get entries => List.unmodifiable(_entries);

  int get totalRequests => _entries.length;

  int get cacheHits => _cacheHits;

  int get dedupedRequests => _deduped;

  int get networkRequests => _network;

  int get errorCount => _errors;

  void clear() {
    if (!kDebugMode) return;
    _entries.clear();
    _countsByIdentity.clear();
    _countsByFeature.clear();
    _cacheHits = 0;
    _deduped = 0;
    _network = 0;
    _errors = 0;
  }

  void record(RequestDiagnosticEntry entry) {
    if (!kDebugMode) return;
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }

    _countsByIdentity[entry.identityKey] =
        (_countsByIdentity[entry.identityKey] ?? 0) + 1;
    final feature = entry.feature ?? 'unknown';
    _countsByFeature[feature] = (_countsByFeature[feature] ?? 0) + 1;

    switch (entry.outcome) {
      case RequestOutcome.cache:
        _cacheHits++;
      case RequestOutcome.deduped:
        _deduped++;
      case RequestOutcome.network:
        _network++;
    }
    if (entry.error) _errors++;
  }

  /// Cache / dedupe hits that never reached Dio.
  void recordLocal({
    required String method,
    required String endpoint,
    required RequestOutcome outcome,
    String? feature,
    String? source,
    String? operation,
  }) {
    if (!kDebugMode) return;
    record(
      RequestDiagnosticEntry(
        method: method,
        endpoint: endpoint,
        normalizedEndpoint: normalizeEndpoint(endpoint),
        timestamp: DateTime.now(),
        durationMs: 0,
        outcome: outcome,
        feature: feature,
        source: source,
        operation: operation,
      ),
    );
  }

  Map<String, int> get countsByFeature => Map.unmodifiable(_countsByFeature);

  /// Identities seen more than once (potential duplicates).
  Map<String, int> get repeatedRequests {
    return {
      for (final entry in _countsByIdentity.entries)
        if (entry.value > 1) entry.key: entry.value,
    };
  }

  List<RequestDiagnosticEntry> get slowRequests {
    return [
      for (final entry in _entries)
        if (entry.durationMs >= 800) entry,
    ];
  }

  RequestDiagnosticsSummary summary() {
    return RequestDiagnosticsSummary(
      totalRequests: totalRequests,
      networkRequests: _network,
      cacheHits: _cacheHits,
      dedupedRequests: _deduped,
      errorCount: _errors,
      byFeature: Map.of(_countsByFeature),
      repeated: repeatedRequests,
      slowCount: slowRequests.length,
    );
  }

  String formatSummary() {
    final s = summary();
    final buf = StringBuffer()
      ..writeln(
        '[API Diagnostics] total=${s.totalRequests} '
        'network=${s.networkRequests} cache=${s.cacheHits} '
        'deduped=${s.dedupedRequests} errors=${s.errorCount} '
        'slow=${s.slowCount}',
      )
      ..writeln('  by feature: ${s.byFeature}')
      ..writeln('  repeated: ${s.repeated}');
    return buf.toString();
  }

  /// Collapse UUID / numeric path segments for grouping.
  static String normalizeEndpoint(String path) {
    final uri = Uri.tryParse(path);
    final raw = uri?.path.isNotEmpty == true ? uri!.path : path;
    final segments = raw.split('/');
    final normalized = [
      for (final segment in segments)
        if (segment.isEmpty)
          segment
        else if (_looksLikeId(segment))
          ':id'
        else
          segment,
    ].join('/');
    return normalized.isEmpty ? '/' : normalized;
  }

  static bool _looksLikeId(String segment) {
    if (RegExp(r'^\d+$').hasMatch(segment)) return true;
    if (RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(segment)) {
      return true;
    }
    // Firebase / cuid-like opaque ids (length + mixed charset).
    if (segment.length >= 16 &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segment) &&
        RegExp(r'[0-9]').hasMatch(segment) &&
        RegExp(r'[A-Za-z]').hasMatch(segment)) {
      return true;
    }
    return false;
  }
}

class RequestDiagnosticsSummary {
  const RequestDiagnosticsSummary({
    required this.totalRequests,
    required this.networkRequests,
    required this.cacheHits,
    required this.dedupedRequests,
    required this.errorCount,
    required this.byFeature,
    required this.repeated,
    required this.slowCount,
  });

  final int totalRequests;
  final int networkRequests;
  final int cacheHits;
  final int dedupedRequests;
  final int errorCount;
  final Map<String, int> byFeature;
  final Map<String, int> repeated;
  final int slowCount;
}

/// Dio [Options.extra] keys for diagnostic tagging.
abstract final class RequestDiagKeys {
  static const feature = 'diag_feature';
  static const source = 'diag_source';
  static const operation = 'diag_operation';
  static const outcome = 'diag_outcome';
  static const startedAt = 'diag_started_at';
}
