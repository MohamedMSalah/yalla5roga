import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
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
          AppNetworkImage.avatar(
            url: member.avatar,
            width: 44.w,
            height: 44.w,
            radius: 12.r,
          ),
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
                if (member.isPending)
                  Text(
                    l10n.pendingGroupRegistration,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: Responsive.fontCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (member.role == GroupRole.owner)
            AppBadge(
              label: l10n.owner.toUpperCase(),
              color: AppColors.brand50,
              textColor: AppColors.brand700,
            )
          else if (canManage)
            IconButton(
              tooltip: l10n.removeMember,
              onPressed: onRemove,
              icon: Icon(
                Icons.remove_circle_outline,
                color: AppColors.rose500,
                size: 20.w,
              ),
            ),
        ],
      ),
    );
  }
}
