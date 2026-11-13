import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/media/media_url_resolver.dart';
import 'package:yalla_5roga/core/media/media_url_store.dart';
import 'package:yalla_5roga/core/network/api_client.dart';

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
  }) {
    return MediaUrlResolver(
      apiClient: client,
      store: store,
      uidProvider: uidProvider ?? () => uid,
      clock: clock,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = MediaUrlStore(prefs);
    requests = [];
  });

  test('resolves references through the batch endpoint and persists them',
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
  });

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
    final resolver = resolverFor(clientWith((options) async {
      throw UnimplementedError();
    }));

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
    final resolver = resolverFor(clientWith((options) async {
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
    }));

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

  test('clearing an account removes its metadata', () async {
    await store.putAll(uid, {
      assetId: MediaUrlEntry(
        url: 'https://signed.example.com/a.jpg',
        visibility: MediaVisibility.private,
      ),
    });
    final resolver = resolverFor(clientWith((options) async {
      throw UnimplementedError();
    }));

    await resolver.clearForAccount(uid);
    expect(store.peek(uid, assetId), isNull);
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
