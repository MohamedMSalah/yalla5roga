import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_actions_section.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_header.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_members_section.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class GroupInfoPage extends StatelessWidget {
  const GroupInfoPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = context.watch<GroupsProvider>();
    if (groups.isInitialLoading) {
      return Scaffold(
        appBar: AppPageBar(title: l10n.groupInfo),
        body: const GroupDetailsSkeleton(),
      );
    }

    final group = groups.findById(groupId);
    if (group == null) {
      return Scaffold(
        appBar: AppPageBar(title: l10n.groupInfo),
        body: AppEmptyState(
          icon: Icons.groups_outlined,
          message: l10n.noGroups,
          compact: true,
        ),
      );
    }

    final canManage = groups.canManage(group);
    final leaving = groups.isLeaving;
    final outingCount = context
        .watch<OutingsProvider>()
        .forGroup(group.id)
        .length;

    return Scaffold(
      appBar: AppPageBar(title: l10n.groupInfo),
      body: ListView(
        padding: Responsive.pagePadding(),
        children: [
          GroupInfoHeader(
            group: group,
            outingCount: outingCount,
            canManage: canManage,
            onChangeImage: () => groups.changeImage(groupId),
          ),
          Responsive.spaceLg.gapH,
          GroupMembersSection(
            members: group.members,
            canManage: canManage,
            onAddMember: () => groups.promptAddMember(groupId),
            onRemoveMember: (person) =>
                groups.confirmRemoveMember(groupId, person),
          ),
          Responsive.spaceLg.gapH,
          GroupInfoActionsSection(
            leaving: leaving,
            onLeaveGroup: leaving
                ? null
                : () => groups.confirmLeaveGroup(groupId),
          ),
          Responsive.spaceLg.gapH,
        ],
      ),
    );
  }
}
