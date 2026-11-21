import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_style.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.groupId,
    required this.name,
    required this.bio,
    required this.image,
    required this.members,
    required this.outings,
    required this.onTap,
  });

  final String groupId;
  final String name;
  final String bio;
  final String image;
  final int? members;
  final int? outings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final description = bio.trim();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final largerText = MediaQuery.textScalerOf(context).scale(17) > 23;
    return DecoratedBox(
      decoration: GroupsStyle.panel(palette, GroupsStyle.cardRadius),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GroupsStyle.cardRadius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: GroupsStyle.cardHeight,
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(
              10,
              GroupsStyle.cardVerticalPadding,
              17,
              GroupsStyle.cardVerticalPadding,
            ),
            child: Row(
              children: [
                AppHero(
                  tag: HeroTags.groupCover(groupId),
                  url: image,
                  radius: 16,
                  child: PlanningCover(
                    url: image,
                    art: PlanningCoverArt.group,
                    width: GroupsStyle.imageSize,
                    height: GroupsStyle.imageSize,
                    radius: 16,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.digits(name),
                        maxLines: largerText ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: GroupsStyle.text(
                          context,
                          18,
                          palette.textPrimary,
                          weight: FontWeight.w700,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.digits(description),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GroupsStyle.text(
                            context,
                            13.5,
                            palette.textSecondary,
                          ),
                        ),
                      ],
                      if (members != null || outings != null) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 19,
                          runSpacing: 5,
                          children: [
                            if (members case final count?)
                              _GroupStatistic(
                                icon: Icons.people_outline_rounded,
                                label: l10n.groupMembersCount(count),
                              ),
                            if (outings case final count?)
                              _GroupStatistic(
                                icon: Icons.calendar_month_outlined,
                                label: l10n.groupOutingsCount(count),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 22,
                  color: palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupStatistic extends StatelessWidget {
  const _GroupStatistic({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tint = context.palette.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label, style: GroupsStyle.text(context, 12, tint)),
        ),
      ],
    );
  }
}
