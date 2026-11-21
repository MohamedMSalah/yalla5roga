import 'package:yalla_5roga/core/widgets/realtime_route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_invitation_history.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/lists/group_outings_list.dart';

class GroupHistoryPage extends StatefulWidget {
  const GroupHistoryPage({
    super.key,
    required this.groupId,
    this.invitations = false,
    this.section = GroupOutingsSection.history,
  });
  final String groupId;
  final bool invitations;
  final GroupOutingsSection section;
  @override
  State<GroupHistoryPage> createState() => _GroupHistoryPageState();
}

class _GroupHistoryPageState extends State<GroupHistoryPage>
    with RealtimeRoute<GroupHistoryPage> {
  @override
  String get realtimeGroupId => widget.groupId;

  late final GroupsProvider _groups;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _groups = context.read<GroupsProvider>()..openGroup(widget.groupId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(forceRefresh: false);
    });
  }

  Future<void> _load({bool forceRefresh = true}) async {
    setState(() => _loading = true);
    await _groups.ensureGroupLoaded(widget.groupId, forceRefresh: forceRefresh);
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _groups.closeGroup(widget.groupId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupsProvider>();
    final group = groups.findById(widget.groupId);
    final accountId = context.select(
      (AuthProvider provider) => provider.user?.id,
    );
    final allowed = group != null && groups.canParticipate(group, accountId);
    return Scaffold(
      appBar: AppPageBar(
        title: widget.invitations
            ? context.l10n.invitationHistory
            : switch (widget.section) {
                GroupOutingsSection.activeVotes => context.l10n.activeVotes,
                GroupOutingsSection.upcoming => context.l10n.upcoming,
                GroupOutingsSection.history => context.l10n.outingHistory,
              },
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: _loading && !allowed
                ? const GroupDetailsSkeleton()
                : !allowed
                ? AppErrorState(
                    message: context.l10n.dataLoadFailed,
                    onRetry: _load,
                  )
                : ListView(
                    padding: Responsive.pagePadding(),
                    children: [
                      Text(group.name, style: context.texts.titleLarge),
                      Responsive.spaceLg.gapH,
                      if (widget.invitations)
                        GroupInvitationHistory(group: group)
                      else
                        GroupOutingsList(group: group, section: widget.section),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
