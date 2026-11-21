import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_controls.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_style.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/invite_friends_banner.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/lists/groups_list.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  var _openingCreate = false;
  var _inviting = false;

  Future<void> _openCreate() async {
    if (_openingCreate) return;
    _openingCreate = true;
    FocusScope.of(context).unfocus();
    try {
      await Get.to(() => const CreateGroupPage());
    } finally {
      _openingCreate = false;
    }
  }

  Future<void> _inviteFriends() async {
    if (_inviting) return;
    final provider = context.read<GroupsProvider>();
    final account = context.read<AuthProvider>();
    final userId = account.user?.id;
    // The current-user list only includes accepted members. Both roles can invite.
    final eligible = provider.groups;
    if (userId == null || eligible.isEmpty) return;

    _inviting = true;
    FocusScope.of(context).unfocus();
    try {
      final groupId = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
        sheetAnimationStyle: AnimationStyle(
          duration: AppMotion.of(context, AppMotion.sheetEnter),
          reverseDuration: AppMotion.of(context, AppMotion.sheetExit),
        ),
        builder: (_) => InviteGroupPicker(groups: eligible),
      );
      if (!mounted ||
          account.user?.id != userId ||
          groupId == null ||
          provider.listedGroup(groupId) == null) {
        return;
      }
      await provider.promptAddMember(groupId);
    } finally {
      _inviting = false;
    }
  }

  void _openDetails(String groupId) {
    FocusScope.of(context).unfocus();
    Get.to(() => GroupDetailsPage(groupId: groupId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GroupsProvider>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return GroupsPageBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey<String>('groups'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(15, 13, 15, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _GroupsSummaryHeader(),
                    const SizedBox(height: 13),
                    CreateGroupButton(onTap: _openCreate),
                    const SizedBox(height: 9),
                    Selector<GroupsProvider, String>(
                      selector: (_, groups) => groups.query,
                      builder: (_, query, _) => GroupSearchBar(
                        query: query,
                        onChanged: provider.setQuery,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Selector<GroupsProvider, GroupsFilter>(
                      selector: (_, groups) => groups.filter,
                      builder: (_, selected, _) => GroupsFilterBar(
                        selected: selected,
                        onSelected: provider.setFilter,
                      ),
                    ),
                    const _GroupsOfflineStatus(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              sliver: GroupsList(onOpenGroup: _openDetails),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                15,
                16,
                15,
                bottomInset + 25,
              ),
              sliver: SliverToBoxAdapter(
                child: Selector<GroupsProvider, bool>(
                  selector: (_, provider) => provider.groups.isNotEmpty,
                  builder: (_, canInvite, _) => InviteFriendsBanner(
                    onTap: canInvite ? _inviteFriends : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsSummaryHeader extends StatelessWidget {
  const _GroupsSummaryHeader();

  @override
  Widget build(BuildContext context) {
    final userId = context.select((AuthProvider auth) => auth.user?.id);
    final (count, friends) = context.select((GroupsProvider groups) {
      final hasCount = groups.hasGroupsSnapshot;
      return (
        hasCount ? groups.groups.length : null,
        hasCount ? groups.uniqueFriendsCount(userId) : null,
      );
    });
    final l10n = context.l10n;
    return GroupsHeader(
      summary: count == null
          ? null
          : friends == null
          ? l10n.groupListSummary(count)
          : l10n.activeGroupsFriends(count, friends),
    );
  }
}

class _GroupsOfflineStatus extends StatelessWidget {
  const _GroupsOfflineStatus();

  @override
  Widget build(BuildContext context) {
    final offline = context.select(
      (AppSyncProvider sync) => sync.status == SyncStatus.offline,
    );
    return offline
        ? const Padding(
            padding: EdgeInsets.only(top: 8),
            child: AppOfflineIndicator(isOffline: true),
          )
        : const SizedBox.shrink();
  }
}
