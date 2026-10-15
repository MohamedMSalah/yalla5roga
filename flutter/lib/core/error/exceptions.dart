class AppException implements Exception {
  const AppException([this.message = 'Unexpected error']);

  final String message;

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error']);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Cache error']);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection']);
}

class AuthException extends AppException {
  const AuthException([super.message = 'Authentication failed', this.code]);

  /// Stable machine code (Firebase Auth code or local), for UI localization.
  final String? code;
}
