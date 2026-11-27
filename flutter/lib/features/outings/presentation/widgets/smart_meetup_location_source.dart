import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_result_handoff_model.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/repositories/smart_meetup_repository.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/pages/group_smart_meetup_page.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/pages/quick_meetup_page.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/pages/smart_meetup_results_page.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/providers/smart_meetup_provider.dart';

class SmartMeetupLocationSource extends StatelessWidget {
  const SmartMeetupLocationSource({
    super.key,
    required this.onPick,
    this.onManual,
  });

  final VoidCallback? onPick, onManual;

  static Future<MeetupResultHandoffModel?> pick(
    BuildContext context, {
    required String? groupId,
    required int limit,
    required bool refresh,
  }) async {
    if (!refresh) {
      return Get.to<MeetupResultHandoffModel>(
        () => groupId == null
            ? QuickMeetupPage(selectionLimit: limit)
            : GroupSmartMeetupPage(groupId: groupId, selectionLimit: limit),
      );
    }
    final auth = context.read<AuthProvider>();
    final owner = auth.user?.id;
    final meetup = SmartMeetupProvider(
      context.read<SmartMeetupRepository>(),
      groupId,
      owner,
    );
    final (String, int, DateTime) target;
    try {
      await meetup.open();
      if (!context.mounted || owner != auth.user?.id) return null;
      final session = meetup.session;
      if (session == null) {
        if (meetup.failure case final failure?) {
          AppSnackBar.showError(
            FailureMessageMapper.localize(failure, context.l10n),
          );
        }
        return null;
      }
      target = (session.id, session.inputVersion, session.expiresAt);
    } finally {
      meetup.dispose();
    }
    final (sessionId, inputVersion, expiresAt) = target;
    return Get.to<MeetupResultHandoffModel>(
      () => SmartMeetupResultsPage(
        sessionId: sessionId,
        inputVersion: inputVersion,
        expiresAt: expiresAt,
        groupId: groupId,
        selectionLimit: limit,
        refreshOnOpen: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    children: [
      TextButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.place_outlined),
        label: Text(context.l10n.smartMeetup),
      ),
      if (onManual != null)
        TextButton(
          onPressed: onManual,
          child: Text(context.l10n.meetupManualLocation),
        ),
    ],
  );
}
