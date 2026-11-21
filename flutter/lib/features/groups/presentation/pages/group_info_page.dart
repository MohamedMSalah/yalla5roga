import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/realtime_route.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/group_bio_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_hero_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_history_links.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_actions_section.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_member_preview.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_members_section.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_name_editor.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/shell_route_navigation.dart';

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

class _GroupInfoPageState extends State<GroupInfoPage>
    with RealtimeRoute<GroupInfoPage> {
  @override
  String get realtimeGroupId => widget.groupId;

  final _membersKey = GlobalKey();
  bool _loading = true;
  late final GroupsProvider _groups;

  @override
  void initState() {
    super.initState();
    _groups = context.read<GroupsProvider>()..openGroup(widget.groupId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _groups.closeGroup(widget.groupId);
    super.dispose();
  }

  Future<void> _load({bool retry = false}) async {
    setState(() => _loading = true);
    await _groups.ensureGroupLoaded(widget.groupId, forceRefresh: retry);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!widget.focusMembers) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _membersKey.currentContext;
      if (mounted && target != null) Scrollable.ensureVisible(target);
    });
  }

  Future<bool> _save(Future<bool> Function() update) async {
    final saved = await update();
    if (saved && mounted) AppSnackBar.show(context.l10n.changesSaved);
    return saved;
  }

  List<GroupMember> _acceptedMembers(Group group) => {
    for (final member in group.members)
      if (!member.isPending &&
          member.id.isNotEmpty &&
          !member.id.startsWith('preview_'))
        member.id: member,
  }.values.toList(growable: false);

  Future<void> _showMembers() async {
    await MemberDisplayName.ensureLoaded();
    if (!mounted) return;
    await AppBottomSheet.show<void>(
      context: context,
      builder: (context) {
        final account = context.select(
          (AuthProvider provider) => provider.user?.id,
        );
        final group = context.select(
          (GroupsProvider provider) => provider.findById(widget.groupId),
        );
        if (group == null || !_groups.canParticipate(group, account)) {
          return Text(context.l10n.dataLoadFailed);
        }
        return GroupMembersSection(
          members: [..._acceptedMembers(group), ...group.pendingMembers],
          canManage: _groups.canManage(group),
          onAddMember: () => _groups.promptAddMember(group.id),
          onRemoveMember: (member) =>
              _groups.confirmRemoveMember(group.id, member),
        );
      },
    );
  }

  void _editName(Group group) {
    AppBottomSheet.show<void>(
      context: context,
      builder: (_) => GroupNameEditor(
        name: group.name,
        onSave: (name) => _save(() => _groups.updateName(group.id, name)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountId = context.select(
      (AuthProvider provider) => provider.user?.id,
    );
    final group = context.select<GroupsProvider, Group?>(
      (provider) =>
          accountId == null ? null : provider.findById(widget.groupId),
    );
    final sync = context.read<AppSyncProvider>();
    final leaving = context.select(
      (GroupsProvider provider) => provider.isLeaving,
    );
    final outingCount = context.select((OutingsProvider provider) {
      final counts = provider.groupOutingCounts;
      return group == null || counts == null ? null : counts[group.id] ?? 0;
    });
    final canParticipate =
        group != null && _groups.canParticipate(group, accountId);
    final canManage =
        group != null && canParticipate && _groups.canManage(group);
    final members = group == null
        ? const <GroupMember>[]
        : _acceptedMembers(group);
    final soleMember =
        canManage && members.length == 1 && group.acceptedMemberCount == 1;
    final lastOwner =
        canManage &&
        !members.any(
          (member) => member.id != accountId && member.role == GroupRole.owner,
        );
    final blockedMessage = soleMember
        ? ((outingCount ?? 0) > 0 ? l10n.groupCannotDeleteWithOutings : null)
        : lastOwner
        ? l10n.groupLastOwnerCannotLeave
        : null;

    return GroupPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: group == null
            ? null
            : ShellRouteNavigation(section: 1, l10n: l10n),
        appBar: GroupPageAppBar(
          title: l10n.groupInfo,
          actions: [
            if (canParticipate)
              GroupPageMenuAction(
                l10n.members,
                Icons.people_outline,
                _showMembers,
              ),
            if (canManage) ...[
              GroupPageMenuAction(
                l10n.groupName,
                Icons.edit_outlined,
                () => _editName(group),
              ),
              GroupPageMenuAction(
                l10n.changeGroupImage,
                Icons.photo_camera_outlined,
                () => _groups.changeImage(group.id),
              ),
            ],
          ],
        ),
        body: group == null
            ? _loading
                  ? const GroupDetailsSkeleton(compact: true)
                  : AppErrorState(
                      message: l10n.dataLoadFailed,
                      onRetry: () => _load(retry: true),
                    )
            : GroupPageList(
                children: [
                  GroupHeroCard(
                    group: group,
                    compact: true,
                    memberCount: group.acceptedMemberCount,
                    outingCount: outingCount,
                  ),
                  const SizedBox(height: 14),
                  GroupBioCard(
                    bio: group.bio,
                    onSave: canManage
                        ? (bio) => _save(() => _groups.updateBio(group.id, bio))
                        : null,
                  ),
                  if (canParticipate) ...[
                    const SizedBox(height: 14),
                    GroupMemberPreview(
                      key: _membersKey,
                      members: members,
                      onView: _showMembers,
                      onInvite: () => _groups.promptAddMember(group.id),
                    ),
                    const SizedBox(height: 14),
                    GroupHistoryLinks(
                      groupId: group.id,
                      canViewInvitations: canParticipate,
                    ),
                    const SizedBox(height: 14),
                    GroupInfoActionsSection(
                      leaving: leaving,
                      deleting: soleMember,
                      blockedMessage: blockedMessage,
                      onAction: () => _groups.confirmLeaveGroup(
                        group.id,
                        delete: soleMember,
                        onSuccess: sync.openLists,
                      ),
                    ),
                  ] else if (_loading) ...[
                    const SizedBox(height: 14),
                    const AppShimmer(
                      child: ShimmerBone(
                        width: double.infinity,
                        height: 104,
                        radius: 19,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
