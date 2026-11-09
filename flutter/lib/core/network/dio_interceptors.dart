import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';

typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});

/// Attaches `Authorization: Bearer <Firebase ID token>` on every request.
///
/// The backend must verify this token and derive the user UID from it —
/// never trust a client-supplied identity field.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({IdTokenProvider? tokenProvider})
    : _tokenProvider = tokenProvider;

  IdTokenProvider? _tokenProvider;
  Dio? _dio;

  /// Must be called once after the owning Dio instance is constructed.
  void bind(Dio dio) => _dio = dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final provider = _tokenProvider;
    if (provider == null) {
      handler.next(options);
      return;
    }

    provider()
        .then((token) {
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (kDebugMode) {
            debugPrint('[DIO] Firebase ID token unavailable: $error');
          }
          // Public endpoints can still proceed. Authenticated endpoints will
          // return a 401, which this interceptor handles below.
          handler.next(options);
        });
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['_authRetried'] == true;
    final provider = _tokenProvider;
    final dio = _dio;
    if (statusCode != 401 || alreadyRetried || provider == null || dio == null) {
      handler.next(err);
      return;
    }

    try {
      final token = await provider(forceRefresh: true);
      if (token == null || token.isEmpty) {
        handler.next(err);
        return;
      }
      final options = err.requestOptions;
      options.extra['_authRetried'] = true;
      options.headers['Authorization'] = 'Bearer $token';
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}

class AppLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[DIO] ${options.method} ${options.uri.path}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Detailed blueprint is logged once in [guardRemote] to avoid duplicates.
    if (kDebugMode) {
      debugPrint(
        '[DIO] Error ${err.response?.statusCode} '
        '${err.requestOptions.method} ${err.requestOptions.uri.path}',
      );
    }
    handler.next(err);
  }
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final AppException exception = ExceptionMapper.appExceptionFromDio(err);

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
        message: exception.message,
      ),
    );
  }
}
