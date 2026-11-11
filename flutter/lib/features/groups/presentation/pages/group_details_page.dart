import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_info_page.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_details_skeleton.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/lists/group_outings_list.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

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
    final palette = context.palette;
    final groups = context.read<GroupsProvider>();
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

    final outingCount = context.select<OutingsProvider, int>(
      (provider) => provider.forGroup(group.id).length,
    );

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
                AppHero(
                  tag: HeroTags.groupCover(group.id),
                  url: group.image,
                  radius: 18.r,
                  child: PlanningCover(
                    url: group.image,
                    art: PlanningCoverArt.group,
                    width: double.infinity,
                    height: 144.h,
                    radius: 18.r,
                  ),
                ),
                Responsive.spaceMd.gapH,
                Semantics(
                  header: true,
                  child: Text(
                    group.name,
                    style: context.texts.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Responsive.spaceXs.gapH,
                Wrap(
                  spacing: Responsive.spaceSm,
                  runSpacing: Responsive.spaceXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.membersOutings(group.memberCount, outingCount),
                      style: context.texts.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    AppBadge(
                      label: groups.roleLabel(group.cuserRole, l10n),
                      color: palette.brandSoft,
                      textColor: palette.brandStrong,
                    ),
                  ],
                ),
                Responsive.spaceLg.gapH,
                CustomButton(
                  label: l10n.createOuting,
                  icon: Icons.add,
                  onPressed: () => Get.to(() => CreateOutingPage(group: group)),
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
