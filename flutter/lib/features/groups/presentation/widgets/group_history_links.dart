import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_history_page.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_section_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';

class GroupHistoryLinks extends StatelessWidget {
  const GroupHistoryLinks({
    super.key,
    required this.groupId,
    required this.canViewInvitations,
  });
  final String groupId;
  final bool canViewInvitations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final border = GroupPageColors(context).border.withValues(alpha: .65);
    return GroupInfoSectionCard(
      title: l10n.groupHistoryTitle,
      icon: Icons.history_rounded,
      body: Column(
        children: [
          if (canViewInvitations) ...[
            Divider(height: 1, indent: 35, color: border),
            GroupInfoNavigationRow(
              icon: Icons.mail_outline,
              label: l10n.invitationHistory,
              onTap: () => Get.to(
                () => GroupHistoryPage(groupId: groupId, invitations: true),
              ),
            ),
          ],
          Divider(height: 1, indent: 35, color: border),
          GroupInfoNavigationRow(
            icon: Icons.history_rounded,
            label: l10n.outingHistory,
            onTap: () => Get.to(() => GroupHistoryPage(groupId: groupId)),
          ),
        ],
      ),
    );
  }
}
