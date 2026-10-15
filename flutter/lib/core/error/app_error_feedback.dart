import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';

enum AppErrorKind { load, send }

/// Console detail + user feedback. Crashlytics is handled separately
/// in [guardRemote] / global handlers to avoid duplicate reports.
class AppErrorFeedback {
  const AppErrorFeedback._();

  static void report(
    Failure failure, {
    required AppErrorKind kind,
    String? context,
  }) {
    final tag = kind == AppErrorKind.load ? 'LOAD' : 'SEND';
    final where = context == null || context.isEmpty ? '' : ' ($context)';
    debugPrint(
      '[AppError/$tag]$where ${failure.runtimeType}: ${failure.message}',
    );

    final ctx = Get.context;
    if (ctx == null) return;

    final l10n = ctx.l10n;
    if (failure is NetworkFailure) {
      AppAlert.networkError(
        title: l10n.connectionErrorTitle,
        message: l10n.connectionErrorHint,
        okText: l10n.ok,
      );
      return;
    }

    AppSnackBar.show(
      kind == AppErrorKind.load ? l10n.dataLoadFailed : l10n.dataSendFailed,
    );
  }
}
