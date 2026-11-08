/// Describes where an error originated for the developer blueprint logger.
class ErrorContext {
  const ErrorContext({
    required this.feature,
    required this.layer,
    required this.operation,
    this.httpMethod,
    this.endpoint,
    this.statusCode,
  });

  final String feature;
  final String layer;
  final String operation;
  final String? httpMethod;
  final String? endpoint;
  final int? statusCode;

  ErrorContext copyWith({
    String? feature,
    String? layer,
    String? operation,
    String? httpMethod,
    String? endpoint,
    int? statusCode,
  }) {
    return ErrorContext(
      feature: feature ?? this.feature,
      layer: layer ?? this.layer,
      operation: operation ?? this.operation,
      httpMethod: httpMethod ?? this.httpMethod,
      endpoint: endpoint ?? this.endpoint,
      statusCode: statusCode ?? this.statusCode,
    );
  }

  /// Best-effort parse of `guardRemote` reason tags like `loadOutings`.
  factory ErrorContext.fromReason(String? reason) {
    final tag = (reason ?? 'remote').trim();
    if (tag.isEmpty) {
      return const ErrorContext(
        feature: 'App',
        layer: 'Repository',
        operation: 'Remote call',
      );
    }

    final lower = tag.toLowerCase();
    final feature = switch (true) {
      _ when lower.contains('outing') || lower.contains('vote') ||
              lower.contains('attendance') || lower.contains('draft') ||
              lower.contains('geocode') || lower.contains('tie') =>
        'Outings',
      _ when lower.contains('group') || lower.contains('member') ||
              lower.contains('invite') =>
        'Groups',
      _ when lower.contains('chat') || lower.contains('message') => 'Chat',
      _ when lower.contains('auth') || lower.contains('login') ||
              lower.contains('register') || lower.contains('otp') ||
              lower.contains('phone') || lower.contains('profile') ||
              lower.contains('password') || lower.contains('email') =>
        'Auth',
      _ when lower.contains('notif') || lower.contains('fcm') ||
              lower.contains('push') =>
        'Notifications',
      _ when lower.contains('discover') || lower.contains('place') ||
              lower.contains('saved') =>
        'Discover',
      _ => 'App',
    };

    final operation = tag
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .trim();

    return ErrorContext(
      feature: feature,
      layer: 'Repository',
      operation: operation.isEmpty ? tag : _capitalize(operation),
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
