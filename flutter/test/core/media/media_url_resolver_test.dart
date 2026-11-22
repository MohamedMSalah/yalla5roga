import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/media/media_url_resolver.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'user-a';
  const assetId = '0f8fad5b-d9cb-469f-a165-70867728950e';
  const otherAssetId = '1a1a1a1a-2222-4333-8444-555555555555';

  late SharedPreferences prefs;
  late MediaUrlStore store;
  late List<RequestOptions> requests;

  ApiClient clientWith(Future<ResponseBody> Function(RequestOptions) handler) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.httpClientAdapter = _StubAdapter(handler);
    return ApiClient(dio);
  }

  MediaUrlResolver resolverFor(
    ApiClient client, {
    String? Function()? uidProvider,
    DateTime Function()? clock,
    Future<bool> Function(String url, {String? cacheKey})? evictCachedImage,
  }) {
    return MediaUrlResolver(
      apiClient: client,
      store: store,
      uidProvider: uidProvider ?? () => uid,
      clock: clock,
      evictCachedImage: evictCachedImage,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = MediaUrlStore(prefs);
    requests = [];
  });

  test(
    'resolves references through the batch endpoint and persists them',
    () async {
      final client = clientWith((options) async {
        requests.add(options);
        final body = Map<String, dynamic>.from(options.data as Map);
        final ids = (body['media_ids'] as List).cast<String>();
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': [
              for (final id in ids)
                {
                  'media_id': id,
                  'url': 'https://signed.example.com/$id.jpg',
                  'visibility': 'private',
                  'expires_at': '2026-11-12T13:00:00.000Z',
                },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      final resolver = resolverFor(client);

      final entries = await Future.wait([
        resolver.resolve(assetId),
        resolver.resolve(otherAssetId),
      ]);

      expect(entries.map((entry) => entry?.url), [
        'https://signed.example.com/$assetId.jpg',
        'https://signed.example.com/$otherAssetId.jpg',
      ]);
      expect(requests, hasLength(1));
      expect(store.peek(uid, assetId)?.visibility, MediaVisibility.private);

      // Fresh cached metadata avoids another network round trip.
      final cached = await resolver.resolve(assetId);
      expect(cached?.url, 'https://signed.example.com/$assetId.jpg');
      expect(requests, hasLength(1));
    },
  );

  test('returns cached metadata when the network fails (offline)', () async {
    await store.putAll(uid, {
      assetId: MediaUrlEntry(
        url: 'https://signed.example.com/stale.jpg',
        visibility: MediaVisibility.private,
        expiresAt: DateTime.utc(2020),
      ),
    });
    final client = clientWith((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final resolver = resolverFor(client);

    final entry = await resolver.resolve(assetId);
    expect(entry?.url, 'https://signed.example.com/stale.jpg');
    // Let the background refresh fail and settle.
    await Future<void>.delayed(Duration.zero);
  });

  test('cache keys are stable and account-scoped for private media', () {
    final resolver = resolverFor(
      clientWith((options) async {
        throw UnimplementedError();
      }),
    );

    final first = resolver.cacheKeyFor(assetId, MediaVisibility.private);
    final second = resolver.cacheKeyFor(assetId, MediaVisibility.private);
    expect(first, second);
    expect(first, contains(uid));
    expect(first, contains(assetId));

    final publicKey = resolver.cacheKeyFor(assetId, MediaVisibility.public);
    expect(publicKey, 'media_public_$assetId');
    expect(
      publicKey,
      isNot(resolver.cacheKeyFor(otherAssetId, MediaVisibility.public)),
    );
  });

  test('http references pass through and media references resolve', () async {
    final resolver = resolverFor(
      clientWith((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': [
              {
                'media_id': assetId,
                'url': 'https://signed.example.com/one.jpg',
                'visibility': 'private',
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }),
    );

    expect(
      await resolver.resolveReference('https://cdn.example.com/a.jpg'),
      'https://cdn.example.com/a.jpg',
    );
    expect(
      await resolver.resolveReference('media://$assetId'),
      'https://signed.example.com/one.jpg',
    );
    expect(await resolver.resolveReference(''), isNull);
  });

  test('a late private response is discarded after account cleanup', () async {
    final started = Completer<RequestOptions>();
    final response = Completer<ResponseBody>();
    final resolver = resolverFor(
      clientWith((options) {
        started.complete(options);
        return response.future;
      }),
    );
    final resolving = resolver.resolve(assetId);
    expect((await started.future).extra[expectedUserIdKey], uid);

    // A later session can restore the same UID, so an identity check alone
    // cannot distinguish the new session from this in-flight response.
    await resolver.clearForAccount(uid);
    response.complete(
      ResponseBody.fromString(
        jsonEncode({
          'data': [
            {
              'media_id': assetId,
              'url': 'https://signed.example.com/previous-session.jpg',
              'visibility': 'private',
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    expect(await resolving, isNull);
    expect(store.peek(uid, assetId), isNull);
  });

  test('splits pending signed URL requests at the API batch limit', () async {
    final sizes = <int>[];
    final resolver = resolverFor(
      clientWith((options) async {
        final body = options.data as Map<String, dynamic>;
        sizes.add((body['media_ids'] as List).length);
        return ResponseBody.fromString(
          '{"data":[]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }),
    );
    await Future.wait(List.generate(51, (i) => resolver.resolve('fixture-$i')));
    expect(sizes, unorderedEquals([50, 1]));
  });

  test('offline logout evicts only that account’s private image', () async {
    const url = 'https://signed.example.com/a.jpg';
    await store.putAll(uid, {
      assetId: MediaUrlEntry(url: url, visibility: MediaVisibility.private),
      otherAssetId: MediaUrlEntry(
        url: 'https://cdn.example.com/places/public.jpg',
        visibility: MediaVisibility.public,
      ),
    });
    await store.putAll('other-account', {
      assetId: MediaUrlEntry(url: url, visibility: MediaVisibility.private),
    });
    final evicted = <(String, String?)>[];
    final resolver = resolverFor(
      clientWith((options) async => throw StateError('Offline')),
      evictCachedImage: (url, {cacheKey}) async {
        evicted.add((url, cacheKey));
        return true;
      },
    );

    await resolver.clearForAccount(uid);
    expect(store.peek(uid, assetId), isNull);
    expect(store.peek(uid, otherAssetId), isNull);
    expect(store.peek('other-account', assetId)?.url, url);
    expect(evicted, [(url, 'media_private_${uid}_$assetId')]);
  });

  test('an authenticated denial evicts a cached private image', () async {
    const url = 'https://signed.example.com/previous.jpg';
    await store.putAll(uid, {
      assetId: MediaUrlEntry(url: url, visibility: MediaVisibility.private),
    });
    final eviction = Completer<(String, String?)>();
    final resolver = resolverFor(
      clientWith(
        (options) async => ResponseBody.fromString(
          '{"data":[]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      ),
      evictCachedImage: (url, {cacheKey}) async {
        eviction.complete((url, cacheKey));
        return true;
      },
    );
    expect(await resolver.revalidate(assetId), isNull);
    expect(store.peek(uid, assetId), isNull);
    expect(await eviction.future, (url, 'media_private_${uid}_$assetId'));
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
