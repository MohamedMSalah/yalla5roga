import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class GroupDetailsHeader extends StatelessWidget {
  const GroupDetailsHeader({super.key, required this.group});
  final Group group;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final groups = context.read<GroupsProvider>();
    final outingCount = context
        .watch<OutingsProvider>()
        .forGroup(group.id)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        if (group.bio.trim().isNotEmpty) ...[
          Responsive.spaceSm.gapH,
          Text(group.bio, style: context.texts.bodyMedium),
        ],
      ],
    );
  }
}
