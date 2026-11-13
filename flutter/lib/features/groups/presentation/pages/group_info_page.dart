import 'package:get/get.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_actions_section.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_header.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_members_section.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({
    super.key,
    required this.groupId,
    this.focusMembers = false,
  });

  final String groupId;
  final bool focusMembers;

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final _membersKey = GlobalKey();
  GroupsProvider? _openGroupProvider;

  @override
  void dispose() {
    _openGroupProvider?.closeGroup(widget.groupId);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _openGroupProvider = context.read<GroupsProvider>()
      ..openGroup(widget.groupId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = _membersKey.currentContext;
      if (widget.focusMembers && target != null) {
        Scrollable.ensureVisible(target);
      }
      await context.read<GroupsProvider>().ensureGroupLoaded(
        widget.groupId,
        forceRefresh: true,
      );
      if (!mounted) return;
      await MemberDisplayName.ensureLoaded();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = context.watch<GroupsProvider>();
    final group = groups.findById(widget.groupId);
    if (groups.isInitialLoading && group == null) {
      return Scaffold(
        appBar: AppPageBar(title: l10n.groupInfo),
        body: const GroupDetailsSkeleton(),
      );
    }

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
    final deleting = groups.isDeletingGroup;
    final outingCount = context
        .watch<OutingsProvider>()
        .forGroup(group.id)
        .length;

    return Scaffold(
      appBar: AppPageBar(title: l10n.groupInfo),
      body: SingleChildScrollView(
        padding: Responsive.pagePadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupInfoHeader(
              group: group,
              outingCount: outingCount,
              canManage: canManage,
              onChangeImage: () => groups.changeImage(widget.groupId),
              onSaveBio: (bio) async {
                final saved = await groups.updateBio(widget.groupId, bio);
                if (saved && context.mounted) {
                  AppSnackBar.show(l10n.changesSaved);
                }
                return saved;
              },
            ),
            Responsive.spaceLg.gapH,
            GroupMembersSection(
              key: _membersKey,
              members: [...group.members, ...group.pendingMembers],
              canManage: canManage,
              onAddMember: () => groups.promptAddMember(widget.groupId),
              onRemoveMember: (person) =>
                  groups.confirmRemoveMember(widget.groupId, person),
            ),
            Responsive.spaceLg.gapH,
            GroupInfoActionsSection(
              leaving: leaving,
              deleting: deleting,
              onDeleteGroup: canManage
                  ? () async {
                      if (leaving ||
                          deleting ||
                          !await AppAlert.confirm(
                            title: l10n.deleteGroup,
                            message: l10n.deleteGroupPrompt,
                            confirmText: l10n.deleteGroup,
                            cancelText: l10n.cancel,
                            destructive: true,
                          )) {
                        return;
                      }
                      if (!context.mounted) return;
                      final outings = context.read<OutingsProvider>();
                      final ok = await groups.deleteGroup(group.id);
                      if (!context.mounted) return;
                      if (!ok) {
                        AppSnackBar.show(groups.errorMessage ?? l10n.tryAgain);
                        return;
                      }
                      await outings.load(forceRefresh: true);
                      Get.until((route) => route.isFirst);
                    }
                  : null,
              onLeaveGroup: leaving || deleting
                  ? null
                  : () => groups.confirmLeaveGroup(widget.groupId),
            ),
            Responsive.spaceLg.gapH,
          ],
        ),
      ),
    );
  }
}
