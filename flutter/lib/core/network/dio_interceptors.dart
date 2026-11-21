import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';

const publicReadKey = "publicRead";
const expectedUserIdKey = "expectedFirebaseUserId";
const authRetriedKey = "authRetried";

typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});

/// Attaches `Authorization: Bearer <Firebase ID token>` on every request.
///
/// The backend must verify this token and derive the user UID from it —
/// never trust a client-supplied identity field.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({this.tokenProvider, this.currentUserId});

  final String? Function()? currentUserId;
  final IdTokenProvider? tokenProvider;

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
  final _reads = <String?, Future<String?>>{};

  Future<String?> _read(IdTokenProvider provider) {
    final uid = currentUserId?.call();
    return _reads.putIfAbsent(
      uid,
      () => Future.sync(provider).whenComplete(() {
        _reads.remove(uid);
      }),
    );
  }

  Future<String?> _refresh(IdTokenProvider provider) {
    final uid = currentUserId?.call();
    return _refreshes.putIfAbsent(
      uid,
      () => Future.sync(() => provider(forceRefresh: true)).whenComplete(() {
        _refreshes.remove(uid);
      }),
    );
  }

  /// Must be called once after the owning Dio instance is constructed.
  void bind(Dio dio) => _dio = dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[publicReadKey] == true) {
      handler.next(options);
      return;
    }
    if (!_sessionMatches(options)) {
      handler.reject(_sessionChanged(options), true);
      return;
    }
    final provider = tokenProvider;
    if (provider == null) {
      handler.next(options);
      return;
    }

    if (options.extra[authRetriedKey] == true) {
      handler.next(options);
      return;
    }
    _read(provider)
        .then((token) {
          if (!_sessionMatches(options)) {
            handler.reject(_sessionChanged(options), true);
            return;
          }
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        })
        .catchError((Object error, StackTrace stackTrace) {
          // Public endpoints can still proceed. Authenticated endpoints will
          // return a 401, which this interceptor handles below.
          if (_sessionMatches(options)) {
            handler.next(options);
          } else {
            handler.reject(_sessionChanged(options), true);
          }
        });
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra[authRetriedKey] == true;
    final provider = tokenProvider;
    final dio = _dio;
    if (err.requestOptions.extra[publicReadKey] == true ||
        err.requestOptions.extra['skip_request_telemetry'] == true ||
        err.requestOptions.path.contains('/auth/recovery/') ||
        err.requestOptions.path.endsWith('/auth/login') ||
        err.requestOptions.path.endsWith('/auth/signup') ||
        err.requestOptions.path.endsWith('/users/sync') ||
        statusCode != 401 ||
        alreadyRetried ||
        provider == null ||
        dio == null ||
        !_sessionMatches(err.requestOptions)) {
      handler.next(err);
      return;
    }

    try {
      final token = await _refresh(provider);
      if (token == null ||
          token.isEmpty ||
          !_sessionMatches(err.requestOptions)) {
        handler.next(err);
        return;
      }
      final options = err.requestOptions;
      options.extra[authRetriedKey] = true;
      options.headers['Authorization'] = 'Bearer $token';
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
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
