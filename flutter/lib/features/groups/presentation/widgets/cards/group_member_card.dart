import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';

class GroupMemberCard extends StatelessWidget {
  const GroupMemberCard({
    super.key,
    required this.member,
    required this.canManage,
    this.onRemove,
  });

  final GroupMember member;
  final bool canManage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final name = MemberDisplayName.resolve(member);

    return AppCard(
      radius: 16,
      child: Row(
        children: [
          UserAvatar(url: member.avatar, size: Responsive.avatarMd),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.digits(name),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontBody,
                  ),
                ),
                if (member.phone != null &&
                    member.phone!.isNotEmpty &&
                    (!member.isPending || member.phone != name))
                  Text(
                    l10n.digits(member.phone!),
                    style: TextStyle(color: palette.textMuted, fontSize: 10.sp),
                  ),
                Responsive.spaceXs.gapH,
                Wrap(
                  spacing: Responsive.spaceXs,
                  runSpacing: Responsive.spaceXs,
                  children: [
                    if (!member.isPending)
                      AppBadge(
                        label: member.role == GroupRole.owner
                            ? l10n.owner
                            : l10n.member,
                        color: palette.brandSoft,
                        textColor: palette.brandStrong,
                      ),
                    AppBadge(
                      label: member.isPending
                          ? l10n.pendingInvitationStatus
                          : l10n.acceptedInvitationStatus,
                      color: member.isPending
                          ? palette.warningSoft
                          : palette.brandSoft,
                      textColor: member.isPending
                          ? palette.warning
                          : palette.brandStrong,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canManage && member.role != GroupRole.owner)
            IconButton(
              tooltip: l10n.removeMember,
              onPressed: onRemove,
              icon: Icon(
                Icons.remove_circle_outline,
                color: context.colors.error,
              ),
            ),
        ],
      ),
    );
  }
}
