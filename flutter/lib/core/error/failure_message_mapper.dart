import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';

/// Maps [Failure] → short localized copy for SnackBars / alerts.
///
/// Never returns raw exception names, HTTP status text, or stack traces.
abstract final class FailureMessageMapper {
  static String localize(Failure failure, L10n l10n) {
    if (failure is NetworkFailure) {
      return failure.code == ErrorCodes.timeout
          ? l10n.errorTimeout
          : l10n.errorNoInternet;
    }

    if (failure is AuthFailure) {
      return l10n.authError(
        failure.code,
        fallback: _byStatusOrCode(failure, l10n),
      );
    }

    if (failure is ValidationFailure) {
      final safe = _safeBusinessMessage(failure.message, l10n);
      return safe ?? l10n.errorValidation;
    }

    if (failure is ParseFailure) {
      return l10n.errorUnexpected;
    }

    if (failure is CacheFailure) {
      return l10n.errorUnexpected;
    }

    return _byStatusOrCode(failure, l10n);
  }

  static String _byStatusOrCode(Failure failure, L10n l10n) {
    // Prefer known product phrases over generic HTTP copy.
    final safe = _safeBusinessMessage(failure.message, l10n);
    if (safe != null) return safe;

    final code = failure.code;
    if (code != null) {
      final fromCode = switch (code) {
        ErrorCodes.network => l10n.errorNoInternet,
        ErrorCodes.timeout => l10n.errorTimeout,
        ErrorCodes.unauthorized ||
        'session-expired' => l10n.errorSessionExpired,
        ErrorCodes.forbidden => l10n.errorForbidden,
        ErrorCodes.notFound => l10n.errorNotFound,
        ErrorCodes.conflict => l10n.errorConflict,
        ErrorCodes.validation => l10n.errorValidation,
        ErrorCodes.server => l10n.errorServer,
        ErrorCodes.parse => l10n.errorUnexpected,
        ErrorCodes.socket => l10n.errorSocket,
        _ => null,
      };
      if (fromCode != null) return fromCode;
    }

    final status = failure.statusCode;
    if (status != null) {
      if (status == 401) return l10n.errorSessionExpired;
      if (status == 403) return l10n.errorForbidden;
      if (status == 404) return l10n.errorNotFound;
      if (status == 409) return l10n.errorConflict;
      if (status == 400 || status == 422) return l10n.errorValidation;
      if (status >= 500) return l10n.errorServer;
    }

    return l10n.errorUnexpected;
  }

  /// Maps a small set of known product phrases; rejects technical / unknown text.
  static String? _safeBusinessMessage(String? raw, L10n l10n) {
    final message = raw?.trim();
    if (message == null || message.isEmpty) return null;
    if (_looksTechnical(message)) return null;

    final lower = message.toLowerCase();
    if (lower.contains('deadline') && lower.contains('pass')) {
      return l10n.voteLocked;
    }
    if (lower.contains('voting') &&
        (lower.contains('closed') || lower.contains('lock'))) {
      return l10n.voteLocked;
    }
    if (lower.contains('attendance') && lower.contains('closed')) {
      return l10n.attendanceClosed;
    }
    if (lower.contains('already') && lower.contains('member')) {
      return l10n.phoneAlreadyAdded;
    }
    return null;
  }

  static bool _looksTechnical(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('exception') ||
        lower.contains('socketexception') ||
        lower.contains('dioexception') ||
        lower.contains('stack trace') ||
        lower.contains('status code') ||
        lower.contains('http/') ||
        lower.contains('errno') ||
        lower.contains('null check') ||
        lower.contains('typeerror') ||
        lower.contains('formatexception') ||
        RegExp(r'\b[45]\d{2}\b').hasMatch(message) ||
        message.contains('{') ||
        message.contains('}')) {
      return true;
    }
    return false;
  }
}
