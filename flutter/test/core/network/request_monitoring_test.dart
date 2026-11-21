import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/cache/cached_remote.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics_interceptor.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_scope.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

void main() {
  final diagnostics = RequestDiagnostics.instance;
  setUp(diagnostics.clear);

  test(
    'expired credential retry gets a new request id in the same operation',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
      addTearDown(() => dio.close(force: true));
      var tokenReads = 0;
      var refreshes = 0;
      final auth = AuthInterceptor(
        currentUserId: () => 'test',
        tokenProvider: ({bool forceRefresh = false}) async {
          if (forceRefresh) {
            refreshes++;
            return 'refreshed-fixture-token';
          }
          tokenReads++;
          return 'expired-fixture-token';
        },
      )..bind(dio);
      final seen = <String>[];
      dio.httpClientAdapter = _Adapter((options) async {
        final id = options.headers['X-Request-ID']! as String;
        seen.add(id);
        expect(options.headers['X-Client-Source'], 'flutter');
        expect(
          options.headers['Authorization'],
          seen.length == 1
              ? 'Bearer expired-fixture-token'
              : 'Bearer refreshed-fixture-token',
        );
        return ResponseBody.fromString(
          '{}',
          seen.length == 1 ? 401 : 200,
          headers: {
            'content-type': ['application/json'],
            'x-request-id': [id],
            'x-route-template': ['/api/groups/:id'],
            'server-timing': ['app;dur=0.10'],
            'content-length': ['2'],
          },
        );
      });
      dio.interceptors.addAll([
        RequestDiagnosticsInterceptor(
          currentUserId: () => 'test',
          firebase: false,
        ),
        auth,
      ]);
      final result = await RequestScope.run(
        () => dio.get<Map<String, dynamic>>('/api/groups/private-fixture-id'),
        origin: 'GroupDetailsPage',
        trigger: 'navigation',
      );
      expect(result.statusCode, 200);
      expect(tokenReads, 1);
      expect(refreshes, 1);
      final entries = diagnostics.entries;
      expect(entries, hasLength(2));
      expect(entries.map((entry) => entry.requestId), seen);
      expect(seen.toSet(), hasLength(2));
      expect(entries.map((entry) => entry.operationId).toSet(), {seen.first});
      expect(entries.map((entry) => entry.trigger), ['navigation', 'retry']);
      expect(entries.map((entry) => entry.endpoint).toSet(), {
        '/api/groups/:id',
      });
      expect(entries.last.serverMs, 0.1);
      expect(entries.last.responseBytes, 2);
      expect(entries.last.source, 'GroupDetailsPage');
    },
  );

  test(
    'concurrent duplicate reads warn while distinct queries do not',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
      addTearDown(() => dio.close(force: true));
      final release = Completer<void>();
      final started = Completer<void>();
      var count = 0;
      dio.httpClientAdapter = _Adapter((options) async {
        if (++count == 3) started.complete();
        await release.future;
        return ResponseBody.fromString('{}', 200);
      });
      dio.interceptors.add(RequestDiagnosticsInterceptor(firebase: false));
      final pending = [
        dio.get<void>(
          '/api/places',
          queryParameters: {'limit': 1, 'search': 'a'},
        ),
        dio.get<void>(
          '/api/places',
          queryParameters: {'search': 'a', 'limit': 1},
        ),
        dio.get<void>(
          '/api/places',
          queryParameters: {'limit': 2, 'search': 'a'},
        ),
      ];
      await started.future;
      release.complete();
      await Future.wait(pending);
      expect(
        diagnostics.entries
            .where((entry) => entry.duplicateCount != null)
            .single
            .concurrent,
        2,
      );
      expect(
        RequestDiagnostics.normalizeEndpoint(
          '/api/users/cuser/fcm-token/private',
        ),
        '/api/users/cuser/fcm-token/:id',
      );
    },
  );

  test(
    'eviction prevents a previous fetch from repopulating the cache',
    () async {
      final cache = TtlCache<String>(ttl: const Duration(minutes: 1));
      final pending = Completer<String>();
      final started = Completer<void>();
      final first = cachedRemote(
        networkInfo: _Online(),
        cache: cache,
        key: 'account:key',
        fetch: () {
          started.complete();
          return pending.future;
        },
      );
      await started.future;
      cache.invalidate('account:key');
      await cachedRemote(
        networkInfo: _Online(),
        cache: cache,
        key: 'account:key',
        fetch: () async => 'fresh',
      );
      pending.complete('obsolete');
      await first;
      expect(cache.get('account:key'), 'fresh');
    },
  );

  test('updating a stale list does not extend its freshness', () {
    final cache = TtlCache<String>(ttl: const Duration(minutes: 1));
    cache.set(
      'list',
      'before',
      fetchedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    cache.updateExisting('list', (_) => 'after');
    expect(cache.get('list'), isNull);
    expect(cache.getStale('list'), 'after');
  });
}

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.run);
  final Future<ResponseBody> Function(RequestOptions options) run;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => run(options);

  @override
  void close({bool force = false}) {}
}
