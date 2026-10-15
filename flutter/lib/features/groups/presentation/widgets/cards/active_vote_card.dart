import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_category_style.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Compact horizontal active-vote card for the Groups screen.
class ActiveVoteCard extends StatelessWidget {
  const ActiveVoteCard({super.key, required this.outing, this.width});

  final Outing outing;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final groups = context.watch<GroupsProvider>();
    final outings = context.watch<OutingsProvider>();
    final groupName = outing.groupId == null
        ? ''
        : groups.findById(outing.groupId!)?.name ?? '';
    final vibe = outing.primaryVibe;
    final voted = outings.hasVoted(outing.id);
    final votedCount = outings.votedCountFor(outing.id);
    final dateLine = outing.dateTimeLine(l10n.digits);
    final cardWidth = width ?? Responsive.voteCardWidth;

    return SizedBox(
      width: cardWidth,
      height: double.infinity,
      child: AppCard(
        padding: Responsive.padding(all: 12),
        onTap: () => Get.to(() => EventPage(event: outing)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName.isEmpty ? l10n.groupsTitle : groupName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.brand700,
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontSm,
              ),
            ),
            Responsive.spaceXs.gapH,
            Row(
              children: [
                IconCircle(
                  icon: vibe.icon,
                  size: 36,
                  iconSize: 16,
                  background: vibe.softBackground,
                  foreground: vibe.accent,
                ),
                Responsive.spaceSm.gapW,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontBody,
                        ),
                      ),
                      Text(
                        l10n.vibeLabel(vibe.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: Responsive.fontCaption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (dateLine.isNotEmpty) ...[
              Responsive.spaceXs.gapH,
              Text(
                dateLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: Responsive.fontCaption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Responsive.spaceXs.gapH,
            Row(
              children: [
                Flexible(
                  child: AppBadge(
                    label: voted ? l10n.youVoted : l10n.voting,
                    color: voted ? AppColors.brand50 : AppColors.amber100,
                    textColor: voted ? AppColors.brand700 : AppColors.amber700,
                  ),
                ),
                Responsive.spaceXs.gapW,
                Text(
                  l10n.votedCount(votedCount, outing.going),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: Responsive.fontCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            CustomButton(
              label: voted ? l10n.viewPlan : l10n.voteNow,
              icon: voted
                  ? Icons.visibility_outlined
                  : Icons.how_to_vote_outlined,
              size: AppButtonSize.small,
              onPressed: () => Get.to(() => EventPage(event: outing)),
            ),
          ],
        ),
      ),
    );
  }
}
