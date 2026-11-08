class AppException implements Exception {
  const AppException([
    this.message = 'Unexpected error',
    this.code,
    this.statusCode,
    this.httpMethod,
    this.endpoint,
    this.responseBody,
  ]);

  final String message;

  /// Stable machine code for localization / classification.
  final String? code;
  final int? statusCode;
  final String? httpMethod;

  /// Path or URI without query secrets when available.
  final String? endpoint;

  /// Raw response payload (sanitized before logging).
  final Object? responseBody;

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'Server error',
    super.code,
    super.statusCode,
    super.httpMethod,
    super.endpoint,
    super.responseBody,
  ]);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Cache error', super.code = 'cache']);
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'No internet connection',
    super.code = 'network',
    super.statusCode,
    super.httpMethod,
    super.endpoint,
    super.responseBody,
  ]);
}

class AuthException extends AppException {
  const AuthException([
    super.message = 'Authentication failed',
    super.code,
    super.statusCode,
    super.httpMethod,
    super.endpoint,
    super.responseBody,
  ]);
}

class ValidationException extends AppException {
  const ValidationException([
    super.message = 'Validation failed',
    super.code = 'validation',
    super.statusCode,
    super.httpMethod,
    super.endpoint,
    super.responseBody,
  ]);
}

class ParseException extends AppException {
  const ParseException([
    super.message = 'Invalid response',
    super.code = 'parse',
    super.statusCode,
    super.httpMethod,
    super.endpoint,
    super.responseBody,
  ]);
}
