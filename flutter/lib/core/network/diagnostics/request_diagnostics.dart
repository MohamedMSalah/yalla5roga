import 'package:flutter/foundation.dart';

/// Outcome of a recorded API attempt (debug diagnostics only).
enum RequestOutcome { network, cache, cacheMiss, stale, deduped }

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
    this.startedAt,
    this.requestId,
    this.operationId,
    this.trigger,
    this.serverMs,
    this.overheadMs,
    this.responseBytes,
    this.cacheStatus,
    this.retry = 0,
    this.errorKind,
    this.duplicateCount,
    this.concurrent,
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
  final DateTime? startedAt;
  final String? requestId;
  final String? operationId;
  final String? trigger;
  final double? serverMs;
  final double? overheadMs;
  final int? responseBytes;
  final String? cacheStatus;
  final int retry;
  final String? errorKind;
  final int? duplicateCount;
  final int? concurrent;

  String get identityKey => '${method.toUpperCase()} $normalizedEndpoint';
}

/// Development-only API request ring buffer and summary.
///
/// No-ops outside [kDebugMode]. Never stores Authorization headers or bodies.
class RequestDiagnostics {
  RequestDiagnostics._();

  static final RequestDiagnostics instance = RequestDiagnostics._();

  static const enabled = bool.fromEnvironment(
    'API_DIAGNOSTICS',
    defaultValue: kDebugMode,
  );
  static const logRequests = bool.fromEnvironment(
    'API_DIAGNOSTICS_LOG',
    defaultValue: kDebugMode,
  );
  static const int maxEntries = 500;
  final List<RequestDiagnosticEntry> _entries = [];

  List<RequestDiagnosticEntry> get entries => List.unmodifiable(_entries);

  int get totalRequests => _entries.length;

  int _count(RequestOutcome outcome) =>
      _entries.where((entry) => entry.outcome == outcome).length;
  int get cacheHits =>
      _count(RequestOutcome.cache) + _count(RequestOutcome.stale);
  int get dedupedRequests => _count(RequestOutcome.deduped);
  int get networkRequests =>
      _entries.where((entry) => entry.requestId != null).length;
  int get errorCount => _entries.where((entry) => entry.error).length;

  void clear() => _entries.clear();

  void record(RequestDiagnosticEntry entry) {
    if (!enabled) return;
    if (_entries.length == maxEntries) _entries.removeAt(0);
    _entries.add(entry);
    if (logRequests && entry.requestId != null) {
      debugPrint(
        '[DIO] ${entry.method} ${entry.normalizedEndpoint} | '
        '${entry.statusCode ?? entry.errorKind ?? 'unknown'} '
        'request=${entry.requestId} operation=${entry.operationId} '
        'origin=${entry.source ?? 'unknown'} trigger=${entry.trigger} '
        'client=${entry.durationMs}ms app=${entry.serverMs ?? 'n/a'}ms '
        'transport/client estimate=${entry.overheadMs?.toStringAsFixed(1) ?? 'n/a'}ms '
        'bytes=${entry.responseBytes ?? 'n/a'} cache=${entry.cacheStatus ?? 'n/a'} retry=${entry.retry}'
        '${entry.duplicateCount == null ? '' : ' potential_duplicate=${entry.duplicateCount} concurrent=${entry.concurrent}'}',
      );
    }
  }

  /// Cache / dedupe hits that never reached Dio.
  void recordLocal({
    required String method,
    required String endpoint,
    required RequestOutcome outcome,
    String? feature,
    String? source,
    String? operation,
    int durationMs = 0,
  }) {
    if (!enabled) return;
    record(
      RequestDiagnosticEntry(
        method: method,
        endpoint: normalizeEndpoint(endpoint),
        normalizedEndpoint: normalizeEndpoint(endpoint),
        timestamp: DateTime.now(),
        durationMs: durationMs,
        outcome: outcome,
        feature: feature,
        source: source,
        operation: operation,
      ),
    );
  }

  Map<String, int> get countsByFeature {
    final counts = <String, int>{};
    for (final entry in _entries) {
      counts.update(
        entry.feature ?? 'unknown',
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return Map.unmodifiable(counts);
  }

  Map<String, int> get repeatedRequests {
    final counts = <String, int>{};
    for (final entry in _entries) {
      final repeats = entry.duplicateCount;
      if (repeats != null) counts[entry.identityKey] = repeats;
    }
    return counts;
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
      networkRequests: networkRequests,
      cacheHits: cacheHits,
      dedupedRequests: dedupedRequests,
      errorCount: errorCount,
      byFeature: countsByFeature,
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

  // Allowed path components from the API inventory. Unknown components may
  // contain account IDs, tokens, file keys or coordinates.
  static const _static = {
    'api',
    'auth',
    'users',
    'groups',
    'outings',
    'notifications',
    'places',
    'invitations',
    'place-brands',
    'media',
    'cuser',
    'signup',
    'login',
    'change-password',
    'verify-password',
    'recovery',
    'start',
    'verify',
    'reset',
    'sync',
    'fcm-token',
    'members',
    'pending-memberships',
    'accept',
    'decline',
    'drafts',
    'saved',
    'save',
    'cancel',
    'attendance',
    'guests',
    'arrivals',
    'self',
    'vote-options',
    'votes',
    'voting-state',
    'tie-break',
    'confirmed-venue',
    'voting',
    'revote',
    'messages',
    'read',
    'branches',
    'geocoding',
    'geojson',
    'recommendations',
    'licenses',
    'categories',
    'vibes',
    'version',
    'changes',
    'status',
    'history',
    'nearby',
    'hours',
    'images',
    'prices',
    'preferences',
    'system-payload',
    'upload-url',
    'signed-urls',
    'confirm',
    'url',
    ':id',
    ':token',
    ':outingId',
    ':groupId',
    ':invitationId',
    ':messageId',
    ':optionId',
    ':userId',
    ':imageId',
    ':priceId',
    ':hourId',
    ':key',
  };

  static String normalizeEndpoint(String path) {
    final raw = path.startsWith('/')
        ? path.split('?').first
        : Uri.tryParse(path)?.path;
    if (raw == null || !raw.startsWith('/api/')) return '/other';
    return raw
        .split('/')
        .map((segment) {
          if (segment.isEmpty || _static.contains(segment)) return segment;
          return ':id';
        })
        .join('/');
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
