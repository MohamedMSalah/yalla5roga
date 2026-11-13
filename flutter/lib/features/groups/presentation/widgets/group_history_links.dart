import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_history_page.dart';

class GroupHistoryLinks extends StatelessWidget {
  const GroupHistoryLinks({super.key, required this.groupId});
  final String groupId;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.mark_email_read_outlined),
        title: Text(context.l10n.invitationHistory),
        trailing: Icon(context.chevronForward),
        onTap: () =>
            Get.to(() => GroupHistoryPage(groupId: groupId, invitations: true)),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history),
        title: Text(context.l10n.outingHistory),
        trailing: Icon(context.chevronForward),
        onTap: () => Get.to(() => GroupHistoryPage(groupId: groupId)),
      ),
    ],
  );
}
