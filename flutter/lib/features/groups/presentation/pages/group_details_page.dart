import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_info_page.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_header.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/lists/group_outings_list.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  bool _loading = true;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadGroup();
    });
  }

  Future<void> _loadGroup() async {
    setState(() => _loading = true);
    await context.read<GroupsProvider>().ensureGroupLoaded(widget.groupId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final group = context.select<GroupsProvider, Group?>(
      (provider) => provider.findById(widget.groupId),
    );
    if (group == null) {
      return Scaffold(
        appBar: AppPageBar(title: l10n.groupDetails),
        body: _loading
            ? const GroupDetailsSkeleton()
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppEmptyState(
                      icon: Icons.groups_outlined,
                      message: l10n.dataLoadFailed,
                      compact: true,
                    ),
                    TextButton(
                      onPressed: _loadGroup,
                      child: Text(l10n.tryAgain),
                    ),
                  ],
                ),
              ),
      );
    }

    return Scaffold(
      appBar: AppPageBar(
        title: l10n.groupDetails,
        trailing: IconButton(
          tooltip: l10n.groupInfo,
          icon: const Icon(Icons.info_outline),
          onPressed: () => Get.to(() => GroupInfoPage(groupId: group.id)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: ListView(
              padding: Responsive.pagePadding(),
              children: [
                GroupDetailsHeader(group: group),
                Responsive.spaceLg.gapH,
                CustomButton(
                  label: l10n.createOuting,
                  icon: Icons.add,
                  onPressed: () => Get.to(() => CreateOutingPage(group: group)),
                ),
                Responsive.spaceXl.gapH,
                GroupOutingsList(
                  group: group,
                  section: GroupOutingsSection.activeVotes,
                ),
                Responsive.spaceXl.gapH,
                GroupOutingsList(group: group),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
