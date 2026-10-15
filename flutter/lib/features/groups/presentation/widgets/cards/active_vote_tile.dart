import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_category_style.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Active vote card used on group details.
class ActiveVoteTile extends StatelessWidget {
  const ActiveVoteTile({super.key, required this.outing});

  final Outing outing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final outings = context.watch<OutingsProvider>();
    final vibe = outing.primaryVibe;
    final voted = outings.hasVoted(outing.id);
    final dateLine = outing.dateTimeLine(l10n.digits);
    final options = outings.optionsFor(outing.id);
    final selected = outings.voteIndexesFor(outing.id);
    final locked = outings.isVoteFinalized(outing.id);

    return AppCard(
      onTap: () => Get.to(() => EventPage(event: outing)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconCircle(
                icon: vibe.icon,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: Responsive.fontBody,
                      ),
                    ),
                    if (dateLine.isNotEmpty)
                      Text(
                        dateLine,
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
              Responsive.spaceXs.gapW,
              AppBadge(
                label: locked
                    ? l10n.youVoted
                    : (voted ? l10n.youVoted : l10n.needsYourVote),
                color: locked || voted ? AppColors.brand50 : AppColors.amber100,
                textColor: locked || voted
                    ? AppColors.brand700
                    : AppColors.amber700,
              ),
            ],
          ),
          if (options.isNotEmpty) ...[
            Responsive.spaceSm.gapH,
            Wrap(
              spacing: Responsive.spaceSm,
              runSpacing: Responsive.spaceSm,
              children: [
                for (var i = 0; i < options.length; i++)
                  _VoteChip(
                    label: options[i].label,
                    selected: selected.contains(i),
                    onTap: locked
                        ? () => AppSnackBar.show(l10n.voteLocked)
                        : () => Get.to(() => EventPage(event: outing)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? AppColors.brand600 : palette.surfaceMuted,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: Responsive.padding(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : palette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: Responsive.fontCaption,
            ),
          ),
        ),
      ),
    );
  }
}
