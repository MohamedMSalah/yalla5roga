import 'package:get/get.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';

enum AppErrorKind { load, send }

/// User-facing feedback only. Developer blueprints are logged in [guardRemote]
/// (and a few non-remote boundaries) to avoid duplicate console noise.
class AppErrorFeedback {
  const AppErrorFeedback._();

  static void report(
    Failure failure, {
    required AppErrorKind kind,
    String? context,
  }) {
    final ctx = Get.context;
    if (ctx == null) return;

    final l10n = ctx.l10n;
    final message = FailureMessageMapper.localize(failure, l10n);

    if (failure is NetworkFailure && failure.code != 'timeout') {
      AppAlert.networkError(
        title: l10n.connectionErrorTitle,
        message: l10n.connectionErrorHint,
        okText: l10n.ok,
      );
      return;
    }

    // Prefer specific mapped copy; fall back to load/send phrasing only when
    // the mapper returned the generic unexpected message for soft UX.
    final text = message == l10n.errorUnexpected
        ? (kind == AppErrorKind.load
              ? l10n.dataLoadFailed
              : l10n.dataSendFailed)
        : message;

    AppSnackBar.showError(text);
  }

  /// Localized message without presenting UI (for callers that own the SnackBar).
  static String messageOf(Failure failure) {
    final l10n = Get.context?.l10n;
    if (l10n == null) return failure.message;
    return FailureMessageMapper.localize(failure, l10n);
  }
}
