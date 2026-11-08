import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';

void main() {
  setUp(() {
    RequestDiagnostics.instance.clear();
  });

  test('normalizeEndpoint collapses ids', () {
    expect(
      RequestDiagnostics.normalizeEndpoint(
        '/api/outings/550e8400-e29b-41d4-a716-446655440000/votes',
      ),
      '/api/outings/:id/votes',
    );
    expect(
      RequestDiagnostics.normalizeEndpoint('/api/groups/42/members'),
      '/api/groups/:id/members',
    );
  });

  test('summary tracks outcomes and repeats', () {
    final diag = RequestDiagnostics.instance;
    diag.record(
      RequestDiagnosticEntry(
        method: 'GET',
        endpoint: '/api/outings/cuser',
        normalizedEndpoint: '/api/outings/cuser',
        timestamp: DateTime.now(),
        durationMs: 120,
        outcome: RequestOutcome.network,
        feature: 'outings',
        statusCode: 200,
      ),
    );
    diag.recordLocal(
      method: 'GET',
      endpoint: 'loadOutings',
      outcome: RequestOutcome.cache,
      feature: 'outings',
    );
    diag.record(
      RequestDiagnosticEntry(
        method: 'GET',
        endpoint: '/api/outings/cuser',
        normalizedEndpoint: '/api/outings/cuser',
        timestamp: DateTime.now(),
        durationMs: 900,
        outcome: RequestOutcome.network,
        feature: 'outings',
        statusCode: 200,
      ),
    );

    final summary = diag.summary();
    expect(summary.totalRequests, 3);
    expect(summary.networkRequests, 2);
    expect(summary.cacheHits, 1);
    expect(summary.byFeature['outings'], 3);
    expect(summary.repeated['GET /api/outings/cuser'], 2);
    expect(summary.slowCount, 1);
  });
}
