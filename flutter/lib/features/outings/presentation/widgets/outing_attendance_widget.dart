import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/avatar_stack.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_going_sheet.dart';

class OutingAttendanceWidget extends StatelessWidget {
  const OutingAttendanceWidget({super.key, required this.outing});
  final Outing outing;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<OutingsProvider>();
    final uid = context.watch<AuthProvider>().user?.id;
    final mine = store.cuserAttendance(outing.id, uid);
    final creator = uid != null && outing.createdById == uid;
    final loaded = store.hasAttendanceFor(outing.id);
    final busy = store.isSavingAttendance(outing.id);
    final enabled =
        uid != null &&
        loaded &&
        !creator &&
        !busy &&
        store.canChangeAttendance(outing.id, userId: uid);
    final members = store.membersForOuting(outing);
    final going = store.goingCountFor(outing.id);
    final avatars = [
      for (final member in members)
        if (store.attendanceFor(outing.id, member.id) == AttendanceStatus.going)
          member.avatar,
    ].take(3).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.attendanceTitle, style: context.texts.titleMedium),
          if (busy) const LinearProgressIndicator(),
          Responsive.spaceSm.gapH,
          Wrap(
            spacing: Responsive.spaceSm,
            runSpacing: Responsive.spaceSm,
            children: [
              for (final status in [
                AttendanceStatus.going,
                AttendanceStatus.maybe,
                AttendanceStatus.notGoing,
              ])
                ChoiceChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  avatar: Icon(AttendanceDisplay.icon(status), size: 18),
                  label: Text(
                    '${switch (status) {
                      AttendanceStatus.going => context.l10n.imIn,
                      AttendanceStatus.maybe => context.l10n.maybe,
                      _ => context.l10n.notIn,
                    }}${loaded ? ' · ${context.l10n.digits(store.attendanceMapFor(outing.id).values.where((v) => v == status).length.toString())}' : ''}',
                  ),
                  selected:
                      mine == status ||
                      (creator && status == AttendanceStatus.going),
                  onSelected: enabled
                      ? (_) => store.setAttendance(outing.id, uid, status)
                      : null,
                ),
            ],
          ),
          if (creator)
            Text(context.l10n.youreIn, style: context.texts.bodySmall)
          else if (loaded && mine == AttendanceStatus.unset)
            Text(context.l10n.noResponse, style: context.texts.bodySmall),
          if (loaded)
            Text(
              context.l10n.attendanceTally(
                context.l10n.noResponse,
                store
                    .attendanceMapFor(outing.id)
                    .values
                    .where((value) => value == AttendanceStatus.unset)
                    .length,
              ),
              style: context.texts.bodySmall,
            ),
          if (loaded) ...[
            Responsive.spaceSm.gapH,
            TextButton(
              onPressed: () => OutingGoingSheet.show(outing),
              child: Wrap(
                spacing: Responsive.spaceSm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (going > 0)
                    AvatarStack(
                      urls: avatars,
                      extra: (going - avatars.length).clamp(0, 99),
                    ),
                  Text(context.l10n.goingCount(going)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon + label helpers for attendance lists.
class AttendanceDisplay {
  const AttendanceDisplay._();

  static IconData icon(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.going => Icons.check,
      AttendanceStatus.notGoing => Icons.close,
      AttendanceStatus.maybe => Icons.help_outline,
      AttendanceStatus.unset => Icons.help_outline,
    };
  }

  static Color color(AttendanceStatus status, Color muted) {
    return switch (status) {
      AttendanceStatus.going => const Color(0xFF059669),
      AttendanceStatus.notGoing => AppColors.rose600,
      AttendanceStatus.maybe => AppColors.amber700,
      AttendanceStatus.unset => muted,
    };
  }

  static String label(AttendanceStatus status, L10n l10n) {
    return switch (status) {
      AttendanceStatus.going => '✓ ${l10n.imIn}',
      AttendanceStatus.notGoing => '✕ ${l10n.notIn}',
      AttendanceStatus.maybe => '? ${l10n.maybe}',
      AttendanceStatus.unset => l10n.noResponse,
    };
  }
}
