import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/error_context.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';

/// Local application error summary. HTTP attempts are recorded by Dio.
abstract final class ErrorBlueprintLogger {
  static void log({
    required Object error,
    StackTrace? stackTrace,
    ErrorContext? context,
    String? possibleCause,
  }) {
    if (!RequestDiagnostics.enabled || !RequestDiagnostics.logRequests) return;
    final endpoint =
        context?.endpoint ?? (error is AppException ? error.endpoint : null);
    debugPrint(
      '[App] ${context?.feature ?? 'App'}/${context?.layer ?? 'App'} '
      '${context?.operation ?? 'Unexpected'} | ${error.runtimeType} '
      '${endpoint == null ? '' : RequestDiagnostics.normalizeEndpoint(endpoint)}',
    );
  }
}
