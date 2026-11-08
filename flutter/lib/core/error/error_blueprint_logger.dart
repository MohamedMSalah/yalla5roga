import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/error_context.dart';
import 'package:yalla_5roga/core/error/error_sanitizer.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';

/// Debug-only structured error dump for Cursor / IDE consoles.
///
/// Never logs Authorization headers, Firebase ID tokens, passwords, or other
/// secrets. Production/profile builds no-op.
abstract final class ErrorBlueprintLogger {
  static const _divider =
      '==================================================';

  /// Logs once per call. Callers must avoid logging the same error again as it
  /// bubbles through layers (prefer [guardRemote] / repository boundaries).
  static void log({
    required Object error,
    StackTrace? stackTrace,
    ErrorContext? context,
    String? possibleCause,
  }) {
    if (!kDebugMode) return;

    final meta = _resolveMeta(error, context);
    final buffer = StringBuffer()
      ..writeln()
      ..writeln(_divider)
      ..writeln('              YALLA 5ROGA ERROR')
      ..writeln(_divider)
      ..writeln('Feature       : ${meta.feature}')
      ..writeln('Layer         : ${meta.layer}')
      ..writeln('Operation     : ${meta.operation}')
      ..writeln('Timestamp     : ${_formatTimestamp(DateTime.now())}')
      ..writeln('Error Type    : ${error.runtimeType}')
      ..writeln('HTTP Method   : ${meta.httpMethod ?? '—'}')
      ..writeln('Endpoint      : ${meta.endpoint ?? '—'}')
      ..writeln('Status Code   : ${meta.statusCode?.toString() ?? '—'}')
      ..writeln()
      ..writeln('ERROR MESSAGE:')
      ..writeln(_messageOf(error))
      ..writeln();

    final response = meta.responseBody;
    if (response != null) {
      buffer
        ..writeln('API RESPONSE:')
        ..writeln(ErrorSanitizer.stringify(response))
        ..writeln();
    }

    buffer
      ..writeln('STACK TRACE:')
      ..writeln(stackTrace ?? StackTrace.current)
      ..writeln()
      ..writeln('POSSIBLE CAUSE:')
      ..writeln(possibleCause ?? _inferCause(error, meta) ?? 'Unknown')
      ..writeln(_divider);

    debugPrint(buffer.toString());
  }

  static _Meta _resolveMeta(Object error, ErrorContext? context) {
    if (error is AppException) {
      return _Meta(
        feature: context?.feature ?? 'App',
        layer: context?.layer ?? 'Data',
        operation: context?.operation ?? 'Operation',
        httpMethod: context?.httpMethod ?? error.httpMethod,
        endpoint: context?.endpoint ?? error.endpoint,
        statusCode: context?.statusCode ?? error.statusCode,
        responseBody: error.responseBody,
      );
    }

    return _Meta(
      feature: context?.feature ?? 'App',
      layer: context?.layer ?? 'App',
      operation: context?.operation ?? 'Unexpected',
      httpMethod: context?.httpMethod,
      endpoint: context?.endpoint,
      statusCode: context?.statusCode,
    );
  }

  static String _messageOf(Object error) {
    if (error is AppException) return error.message;
    return ErrorSanitizer.stringify(error.toString(), maxLength: 1500);
  }

  static String _formatTimestamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  static String? _inferCause(Object error, _Meta meta) {
    if (error is NetworkException) {
      return error.code == 'timeout'
          ? 'Request timed out — slow network or server unresponsive'
          : 'Device appears offline or cannot reach the API host';
    }
    if (error is AuthException &&
        (error.code == 'unauthorized' || meta.statusCode == 401)) {
      return 'Firebase session missing/expired or backend rejected the ID token';
    }
    if (meta.statusCode == 403) {
      return 'Caller is authenticated but not allowed for this outing/group action';
    }
    if (meta.statusCode == 404) {
      return 'Resource id is stale, deleted, or never existed';
    }
    if (meta.statusCode == 409) {
      return 'Business conflict (closed vote, duplicate, invalid state transition)';
    }
    if (meta.statusCode == 422 || meta.statusCode == 400) {
      return 'Request payload failed validation';
    }
    if (meta.statusCode != null && meta.statusCode! >= 500) {
      return 'Backend or upstream dependency failed';
    }
    if (error is FormatException ||
        (error is AppException && error.code == 'parse')) {
      return 'Response JSON shape does not match the expected client model';
    }
    return null;
  }
}

class _Meta {
  const _Meta({
    required this.feature,
    required this.layer,
    required this.operation,
    this.httpMethod,
    this.endpoint,
    this.statusCode,
    this.responseBody,
  });

  final String feature;
  final String layer;
  final String operation;
  final String? httpMethod;
  final String? endpoint;
  final int? statusCode;
  final Object? responseBody;
}
