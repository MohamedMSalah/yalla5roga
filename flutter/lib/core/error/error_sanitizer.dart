/// Strips secrets and private fields from request/response payloads for logs.
abstract final class ErrorSanitizer {
  static const _sensitiveKeys = {
    'password',
    'passwd',
    'token',
    'access_token',
    'accessToken',
    'refresh_token',
    'refreshToken',
    'id_token',
    'idToken',
    'customToken',
    'custom_token',
    'authorization',
    'auth',
    'secret',
    'api_key',
    'apiKey',
    'firebase_token',
    'firebaseToken',
    'otp',
    'verification_code',
    'verificationCode',
    'phone',
    'phone_number',
    'phoneNumber',
    'email',
    'national_id',
    'nationalId',
  };

  static Object? sanitize(Object? value, {int depth = 0}) {
    if (value == null) return null;
    if (depth > 6) return '[truncated]';

    if (value is Map) {
      final out = <String, Object?>{};
      value.forEach((key, dynamic entry) {
        final name = key.toString();
        if (_isSensitiveKey(name)) {
          out[name] = '***';
        } else {
          out[name] = sanitize(entry, depth: depth + 1);
        }
      });
      return out;
    }

    if (value is Iterable) {
      return [
        for (final item in value.take(40)) sanitize(item, depth: depth + 1),
        if (value.length > 40) '...(${value.length - 40} more)',
      ];
    }

    if (value is String) {
      return _sanitizeString(value);
    }

    return value;
  }

  static String stringify(Object? value, {int maxLength = 4000}) {
    final cleaned = sanitize(value);
    final text = cleaned?.toString() ?? 'null';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}… [truncated]';
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.trim().toLowerCase().replaceAll('-', '_');
    if (_sensitiveKeys.contains(key) || _sensitiveKeys.contains(normalized)) {
      return true;
    }
    return normalized.contains('password') ||
        normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('authorization');
  }

  static String _sanitizeString(String value) {
    var text = value;
    // Bearer tokens
    text = text.replaceAllMapped(
      RegExp(r'(Bearer\s+)(\S+)', caseSensitive: false),
      (m) => '${m[1]}***',
    );
    // Long JWT-like blobs
    text = text.replaceAllMapped(
      RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'),
      (_) => '***JWT***',
    );
    if (text.length > 2000) {
      return '${text.substring(0, 2000)}… [truncated]';
    }
    return text;
  }
}
