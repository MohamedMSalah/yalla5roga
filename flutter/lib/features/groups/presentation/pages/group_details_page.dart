import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_scope.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/realtime_route.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_history_page.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_info_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_hero_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/lists/group_outings_list.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/shell_route_navigation.dart';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage>
    with RealtimeRoute<GroupDetailsPage> {
  @override
  String get realtimeGroupId => widget.groupId;

  bool _loading = true;
  bool _openingCreate = false;
  late final GroupsProvider _groups;

  @override
  void initState() {
    super.initState();
    _groups = context.read<GroupsProvider>()..openGroup(widget.groupId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadGroup();
    });
  }

  @override
  void dispose() {
    _groups.closeGroup(widget.groupId);
    super.dispose();
  }

  Future<void> _loadGroup({bool retry = false}) async {
    setState(() => _loading = true);
    await RequestScope.run(
      () => _groups.ensureGroupLoaded(widget.groupId, forceRefresh: retry),
      origin: 'GroupDetailsPage', trigger: retry ? 'manual_refresh' : 'navigation',
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createOuting() async {
    final group = _groups.findById(widget.groupId);
    if (_openingCreate ||
        group == null ||
        !_groups.canParticipate(group, context.read<AuthProvider>().user?.id)) {
      return;
    }
    _openingCreate = true;
    try {
      await Get.to(() => CreateOutingPage(group: group));
    } finally {
      _openingCreate = false;
    }
  }

  void _showOutings(GroupOutingsSection section) {
    Get.to(() => GroupHistoryPage(groupId: widget.groupId, section: section));
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
    final outingCount = context.select((OutingsProvider provider) {
      final counts = provider.groupOutingCounts;
      return group == null || counts == null ? null : counts[group.id] ?? 0;
    });
    final canParticipate =
        group != null && _groups.canParticipate(group, accountId);

    return GroupPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: group == null
            ? null
            : ShellRouteNavigation(section: 1, l10n: l10n),
        appBar: GroupPageAppBar(
          title: l10n.groupDetails,
          actions: [
            if (group != null)
              GroupPageMenuAction(
                l10n.groupInfo,
                Icons.info_outline,
                () => Get.to(() => GroupInfoPage(groupId: group.id)),
              ),
          ],
        ),
        body: group == null
            ? _loading
                  ? const GroupDetailsSkeleton()
                  : AppErrorState(
                      message: l10n.dataLoadFailed,
                      onRetry: () => _loadGroup(retry: true),
                    )
            : GroupPageList(
                children: [
                  GroupHeroCard(
                    group: group,
                    memberCount: group.acceptedMemberCount,
                    outingCount: outingCount,
                    role: canParticipate
                        ? _groups.roleLabel(group.cuserRole, l10n)
                        : null,
                  ),
                  if (canParticipate) ...[
                    const SizedBox(height: 14),
                    GroupActionButton(
                      label: l10n.createOuting,
                      icon: Icons.add,
                      onTap: _createOuting,
                    ),
                    GroupOutingsList(
                      group: group,
                      section: GroupOutingsSection.activeVotes,
                      preview: true,
                      onCreate: _createOuting,
                      onSeeAll: () =>
                          _showOutings(GroupOutingsSection.activeVotes),
                    ),
                    GroupOutingsList(
                      group: group,
                      preview: true,
                      onSeeAll: () =>
                          _showOutings(GroupOutingsSection.upcoming),
                    ),
                  ] else if (_loading) ...[
                    const SizedBox(height: 14),
                    const AppShimmer(
                      child: ShimmerBone(
                        width: double.infinity,
                        height: 48,
                        radius: 24,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
