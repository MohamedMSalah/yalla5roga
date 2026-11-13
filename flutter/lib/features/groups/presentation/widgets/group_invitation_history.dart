import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/invitation_card.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/presentation/invitation_l10n.dart';

class GroupInvitationHistory extends StatelessWidget {
  const GroupInvitationHistory({super.key, required this.group});
  final Group group;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (group.invitationHistory.isEmpty) {
      return AppEmptyState(message: l10n.noInvitations, compact: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in group.invitationHistory) ...[
          InvitationCard(
            title: l10n.digits(
              item.inviteeName.isEmpty ? item.phone : item.inviteeName,
            ),
            subtitle: [
              l10n.invitedBy(item.inviterName),
              l10n.formatWhen(item.createdAt),
            ].join(' · '),
            avatar: UserAvatar(url: group.image, size: Responsive.avatarMd),
            acceptLabel: l10n.accept,
            declineLabel: l10n.decline,
            showActions: false,
            status: AppBadge(
              label: InvitationStatus.fromApi(item.status).label(l10n),
              color: item.status == 'pending'
                  ? context.palette.warningSoft
                  : context.palette.brandSoft,
              textColor: item.status == 'pending'
                  ? context.palette.warning
                  : context.palette.brandStrong,
            ),
          ),
          Responsive.spaceMd.gapH,
        ],
      ],
    );
  }
}
