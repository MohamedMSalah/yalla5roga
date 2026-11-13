import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/group_card.dart' as shared;
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, this.onTap});

  final Group group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outingCount = context
        .watch<OutingsProvider>()
        .forGroup(group.id)
        .length;

    return shared.GroupCard(
      title: group.name,
      description: group.bio,
      subtitle: l10n.membersOutings(group.memberCount, outingCount),
      onTap: onTap,
      cover: AppHero(
        tag: HeroTags.groupCover(group.id),
        url: group.image,
        radius: 16.r,
        child: PlanningCover(
          url: group.image,
          art: PlanningCoverArt.group,
          width: 56.w,
          height: 56.w,
        ),
      ),
    );
  }
}
