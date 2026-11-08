import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';

typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});

/// Attaches `Authorization: Bearer <Firebase ID token>` on every request.
///
/// The backend must verify this token and derive the user UID from it —
/// never trust a client-supplied identity field.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({IdTokenProvider? tokenProvider})
    : _tokenProvider = tokenProvider;

  IdTokenProvider? _tokenProvider;

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
          // Proceed without a token rather than blocking the request pipeline.
          handler.next(options);
        });
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
