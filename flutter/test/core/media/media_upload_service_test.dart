import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/media/media_upload_service.dart';
import 'package:yalla_5roga/core/network/api_client.dart';

void main() {
  const mediaId = '0f8fad5b-d9cb-469f-a165-70867728950e';

  late Directory tempDir;
  late File imageFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('yalla_media_test');
    imageFile = File('${tempDir.path}/avatar.jpg');
    await imageFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ApiClient apiClientWith(Future<ResponseBody> Function(RequestOptions) handler) {
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
    dio.httpClientAdapter = _StubAdapter(handler);
    return ApiClient(dio);
  }

  ResponseBody jsonResponse(Object body, [int status = 200]) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  test('uploads bytes directly to storage, confirms, and returns a reference',
      () async {
    final apiCalls = <String>[];
    final apiClient = apiClientWith((options) async {
      apiCalls.add('${options.method} ${options.path}');
      if (options.path.endsWith('/upload-url')) {
        return jsonResponse({
          'success': true,
          'data': {
            'media_id': mediaId,
            'object_key': 'profiles/2026-11/avatar.jpg',
            'visibility': 'private',
            'status': 'pending',
            'upload_url': 'https://storage.test/put/avatar.jpg',
            'upload_expires_at': '2026-11-12T13:00:00.000Z',
          },
        }, 201);
      }
      if (options.path.endsWith('/confirm')) {
        return jsonResponse({
          'success': true,
          'data': {
            'media_id': mediaId,
            'visibility': 'private',
            'status': 'ready',
          },
        });
      }
      return jsonResponse({'success': false}, 404);
    });

    Uint8List? storedBytes;
    String? storedContentType;
    final storageDio = Dio();
    storageDio.httpClientAdapter = _StubAdapter((options) async {
      storedBytes = options.data as Uint8List?;
      storedContentType =
          '${options.headers[Headers.contentTypeHeader] ?? ''}';
      return ResponseBody.fromString('', 200);
    });

    final service = MediaUploadService(
      apiClient: apiClient,
      storageDio: storageDio,
      apiBaseUrl: 'http://api.test',
    );

    final uploaded = await service.uploadLocalImage(
      path: imageFile.path,
      purpose: MediaPurpose.profile,
    );

    expect(uploaded.mediaId, mediaId);
    expect(uploaded.reference, 'media://$mediaId');
    expect(uploaded.visibility, isNotNull);
    expect(storedBytes?.toList(), [1, 2, 3, 4]);
    expect(storedContentType, 'image/jpeg');
    expect(apiCalls, [
      'POST /api/media/upload-url',
      'POST /api/media/$mediaId/confirm',
    ]);
  });

  test('failed confirm deletes the pending intent', () async {
    final apiCalls = <String>[];
    final apiClient = apiClientWith((options) async {
      apiCalls.add('${options.method} ${options.path}');
      if (options.path.endsWith('/upload-url')) {
        return jsonResponse({
          'success': true,
          'data': {
            'media_id': mediaId,
            'upload_url': 'https://storage.test/put/avatar.jpg',
            'visibility': 'private',
          },
        }, 201);
      }
      if (options.path.endsWith('/confirm')) {
        return jsonResponse({
          'success': false,
          'message': 'Uploaded object was not found in storage',
        }, 409);
      }
      return jsonResponse({'success': true, 'data': {'deleted': true}});
    });
    final storageDio = Dio();
    storageDio.httpClientAdapter = _StubAdapter(
      (options) async => ResponseBody.fromString('', 200),
    );
    final service = MediaUploadService(
      apiClient: apiClient,
      storageDio: storageDio,
    );

    await expectLater(
      service.uploadLocalImage(
        path: imageFile.path,
        purpose: MediaPurpose.profile,
      ),
      throwsA(isA<MediaUploadException>()),
    );

    expect(apiCalls, [
      'POST /api/media/upload-url',
      'POST /api/media/$mediaId/confirm',
      'DELETE /api/media/$mediaId',
    ]);
  });

  test('rejects unsupported formats and oversized files before networking',
      () async {
    var calls = 0;
    final service = MediaUploadService(
      apiClient: apiClientWith((options) async {
        calls += 1;
        throw UnimplementedError();
      }),
      maxUploadBytes: 2,
    );

    await expectLater(
      service.uploadLocalImage(
        path: imageFile.path,
        purpose: MediaPurpose.profile,
      ),
      throwsA(
        isA<MediaUploadException>().having(
          (error) => error.message,
          'message',
          contains('too large'),
        ),
      ),
    );

    final heic = File('${tempDir.path}/photo.heic');
    await heic.writeAsBytes([1]);
    await expectLater(
      service.uploadLocalImage(
        path: heic.path,
        purpose: MediaPurpose.profile,
      ),
      throwsA(
        isA<MediaUploadException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported image format'),
        ),
      ),
    );
    expect(calls, 0);
  });

  test('rewrites mock loopback upload hosts to the configured API host',
      () async {
    final apiClient = apiClientWith((options) async {
      if (options.path.endsWith('/upload-url')) {
        return jsonResponse({
          'success': true,
          'data': {
            'media_id': mediaId,
            'upload_url': 'http://localhost:3000/api/media/mock-upload/key',
            'visibility': 'private',
          },
        }, 201);
      }
      return jsonResponse({
        'success': true,
        'data': {'visibility': 'private', 'status': 'ready'},
      });
    });

    String? putUrl;
    final storageDio = Dio();
    storageDio.httpClientAdapter = _StubAdapter((options) async {
      putUrl = options.uri.toString();
      return ResponseBody.fromString('', 200);
    });
    final service = MediaUploadService(
      apiClient: apiClient,
      storageDio: storageDio,
      apiBaseUrl: 'http://10.0.2.2:3000',
    );

    await service.uploadLocalImage(
      path: imageFile.path,
      purpose: MediaPurpose.profile,
    );

    expect(putUrl, 'http://10.0.2.2:3000/api/media/mock-upload/key');
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
