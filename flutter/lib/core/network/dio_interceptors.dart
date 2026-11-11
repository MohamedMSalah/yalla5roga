import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';

const expectedUserIdKey = "expectedFirebaseUserId";

typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});

/// Attaches `Authorization: Bearer <Firebase ID token>` on every request.
///
/// The backend must verify this token and derive the user UID from it —
/// never trust a client-supplied identity field.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({IdTokenProvider? tokenProvider, this.currentUserId})
    : _tokenProvider = tokenProvider;

  final String? Function()? currentUserId;
  IdTokenProvider? _tokenProvider;

  bool _sessionMatches(RequestOptions options) {
    final expected = options.extra[expectedUserIdKey];
    return expected == null || currentUserId?.call() == expected;
  }

  DioException _sessionChanged(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.cancel,
    error: const AuthException('Account changed'),
  );
  Dio? _dio;
  final _refreshes = <String?, Future<String?>>{};

  Future<String?> _refresh(IdTokenProvider provider) {
    final uid = currentUserId?.call();
    return _refreshes.putIfAbsent(uid, () =>
      provider(forceRefresh: true).whenComplete(() => _refreshes.remove(uid)),
    );
  }

  /// Must be called once after the owning Dio instance is constructed.
  void bind(Dio dio) => _dio = dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_sessionMatches(options)) {
      handler.reject(_sessionChanged(options));
      return;
    }
    final provider = _tokenProvider;
    if (provider == null) {
      handler.next(options);
      return;
    }

    provider()
        .then((token) {
          if (!_sessionMatches(options)) {
            handler.reject(_sessionChanged(options));
            return;
          }
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
          if (_sessionMatches(options)) {
            handler.next(options);
          } else {
            handler.reject(_sessionChanged(options));
          }
        });
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['_authRetried'] == true;
    final provider = _tokenProvider;
    final dio = _dio;
    if (err.requestOptions.path.contains('/auth/recovery/') || err.requestOptions.path.endsWith('/auth/login') || err.requestOptions.path.endsWith('/auth/signup') || err.requestOptions.path.endsWith('/users/sync') || statusCode != 401 || alreadyRetried || provider == null || dio == null || !_sessionMatches(err.requestOptions)) {
      handler.next(err);
      return;
    }

    try {
      final token = await _refresh(provider);
      if (token == null || token.isEmpty || !_sessionMatches(err.requestOptions)) {
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
