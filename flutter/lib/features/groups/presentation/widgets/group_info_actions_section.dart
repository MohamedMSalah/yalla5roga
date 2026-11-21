import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_section_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';

class GroupInfoActionsSection extends StatelessWidget {
  const GroupInfoActionsSection({
    super.key,
    required this.deleting,
    required this.leaving,
    required this.onAction,
    this.blockedMessage,
  });

  final bool deleting, leaving;
  final VoidCallback? onAction;
  final String? blockedMessage;

  @override
  Widget build(BuildContext context) => GroupInfoSectionCard(
    title: context.l10n.groupActions,
    icon: Icons.settings_outlined,
    body: blockedMessage != null
        ? Text(
            blockedMessage!,
            style: context.texts.bodyMedium?.copyWith(
              color: GroupPageColors(context).muted,
            ),
          )
        : GroupActionButton(
            label: deleting
                ? context.l10n.deleteGroup
                : context.l10n.leaveGroup,
            icon: deleting ? Icons.delete_outline : Icons.logout_outlined,
            destructive: true,
            loading: leaving,
            onTap: leaving ? null : onAction,
          ),
  );
}
