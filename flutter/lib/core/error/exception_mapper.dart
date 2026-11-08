import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/error/failures.dart';

/// Converts thrown errors into typed [Failure]s for repositories.
abstract final class ExceptionMapper {
  static Failure toFailure(Object error) {
    if (error is AuthException) {
      return AuthFailure(error.message, error.code, error.statusCode);
    }
    if (error is NetworkException) {
      return NetworkFailure(
        error.message,
        error.code ?? ErrorCodes.network,
        error.statusCode,
      );
    }
    if (error is ValidationException) {
      return ValidationFailure(
        error.message,
        error.code ?? ErrorCodes.validation,
        error.statusCode,
      );
    }
    if (error is ParseException) {
      return ParseFailure(
        error.message,
        error.code ?? ErrorCodes.parse,
        error.statusCode,
      );
    }
    if (error is CacheException) {
      return CacheFailure(error.message, error.code ?? ErrorCodes.cache);
    }
    if (error is AppException) {
      return ServerFailure(
        error.message,
        error.code ?? _codeForStatus(error.statusCode),
        error.statusCode,
      );
    }
    if (error is DioException) {
      return fromDio(error);
    }
    if (error is FormatException) {
      return ParseFailure(error.message, ErrorCodes.parse);
    }
    return ServerFailure(error.toString(), ErrorCodes.unexpected);
  }

  static Failure fromDio(DioException error) {
    if (error.error is AppException) {
      return toFailure(error.error!);
    }

    final status = error.response?.statusCode;
    final message = _messageFromBody(error) ?? error.message ?? 'Server error';

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkFailure(message, ErrorCodes.timeout, status);
      case DioExceptionType.connectionError:
        return NetworkFailure(message, ErrorCodes.network, status);
      default:
        break;
    }

    return ServerFailure(message, _codeForStatus(status), status);
  }

  /// Builds a typed [AppException] from a Dio failure (used by interceptors).
  static AppException appExceptionFromDio(DioException err) {
    final message = _messageFromBody(err) ?? err.message ?? 'Unexpected error';
    final status = err.response?.statusCode;
    final method = err.requestOptions.method;
    final endpoint = err.requestOptions.uri.path;
    final body = err.response?.data;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message,
          ErrorCodes.timeout,
          status,
          method,
          endpoint,
          body,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message,
          ErrorCodes.network,
          status,
          method,
          endpoint,
          body,
        );
      default:
        break;
    }

    return switch (status) {
      401 => AuthException(
        message,
        ErrorCodes.unauthorized,
        status,
        method,
        endpoint,
        body,
      ),
      403 => ServerException(
        message,
        ErrorCodes.forbidden,
        status,
        method,
        endpoint,
        body,
      ),
      404 => ServerException(
        message,
        ErrorCodes.notFound,
        status,
        method,
        endpoint,
        body,
      ),
      409 => ServerException(
        message,
        ErrorCodes.conflict,
        status,
        method,
        endpoint,
        body,
      ),
      400 || 422 => ValidationException(
        message,
        ErrorCodes.validation,
        status,
        method,
        endpoint,
        body,
      ),
      _ when status != null && status >= 500 => ServerException(
        message,
        ErrorCodes.server,
        status,
        method,
        endpoint,
        body,
      ),
      _ => ServerException(
        message,
        _codeForStatus(status),
        status,
        method,
        endpoint,
        body,
      ),
    };
  }

  static String? _codeForStatus(int? status) {
    return switch (status) {
      401 => ErrorCodes.unauthorized,
      403 => ErrorCodes.forbidden,
      404 => ErrorCodes.notFound,
      409 => ErrorCodes.conflict,
      400 || 422 => ErrorCodes.validation,
      _ when status != null && status >= 500 => ErrorCodes.server,
      _ => ErrorCodes.unexpected,
    };
  }

  static String? _messageFromBody(DioException err) {
    final data = err.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
