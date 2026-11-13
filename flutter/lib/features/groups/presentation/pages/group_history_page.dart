import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_invitation_history.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/lists/group_outings_list.dart';

class GroupHistoryPage extends StatefulWidget {
  const GroupHistoryPage({
    super.key,
    required this.groupId,
    this.invitations = false,
  });
  final String groupId;
  final bool invitations;
  @override
  State<GroupHistoryPage> createState() => _GroupHistoryPageState();
}

class _GroupHistoryPageState extends State<GroupHistoryPage> {
  late final GroupsProvider _groups;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _groups = context.read<GroupsProvider>()..openGroup(widget.groupId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _groups.ensureGroupLoaded(widget.groupId, forceRefresh: true);
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
    return Scaffold(
      appBar: AppPageBar(
        title: widget.invitations
            ? context.l10n.invitationHistory
            : context.l10n.outingHistory,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: _loading && group == null
                ? const GroupDetailsSkeleton()
                : group == null
                ? AppErrorState(
                    message: context.l10n.dataLoadFailed,
                    onRetry: _load,
                  )
                : ListView(
                    padding: Responsive.pagePadding(),
                    children: [
                      if (_loading) const LinearProgressIndicator(),
                      Text(group.name, style: context.texts.titleLarge),
                      Responsive.spaceLg.gapH,
                      if (widget.invitations)
                        GroupInvitationHistory(group: group)
                      else
                        GroupOutingsList(
                          group: group,
                          section: GroupOutingsSection.history,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
