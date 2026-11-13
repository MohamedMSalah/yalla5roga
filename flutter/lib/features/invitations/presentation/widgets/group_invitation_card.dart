import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/features/invitations/presentation/invitation_l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/invitation_card.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';

class GroupInvitationCard extends StatelessWidget {
  const GroupInvitationCard({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
    required this.isAccepting,
    required this.isDeclining,
  });
  final GroupInvitation invitation;
  final VoidCallback? onAccept, onDecline;
  final bool isAccepting, isDeclining;
  @override
  Widget build(BuildContext context) => InvitationCard(
    title: invitation.groupName,
    subtitle:
        '${context.l10n.invitedYouToJoin(invitation.inviterName)} · ${context.l10n.formatWhen(invitation.createdAt)}',
    avatar: UserAvatar(url: invitation.groupImage, size: 48.w),
    showActions: invitation.status == InvitationStatus.pending,
    status: AppBadge(
      label: invitation.status.label(context.l10n),
      color: invitation.status == InvitationStatus.pending
          ? context.palette.warningSoft
          : context.palette.brandSoft,
      textColor: invitation.status == InvitationStatus.pending
          ? context.palette.warning
          : context.palette.brandStrong,
    ),
    acceptLabel: context.l10n.accept,
    declineLabel: context.l10n.decline,
    onAccept: onAccept,
    onDecline: onDecline,
    isAccepting: isAccepting,
    isDeclining: isDeclining,
  );
}
