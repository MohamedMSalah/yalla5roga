import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';

abstract final class StaleMeetupResultDialog {
  static Future<bool> show(BuildContext context) {
    final l10n = context.l10n;
    return AppAlert.confirm(
      title: l10n.smartMeetup,
      message: l10n.meetupStaleResults,
      confirmText: l10n.meetupRefreshResults,
      cancelText: l10n.cancel,
    );
  }
}
