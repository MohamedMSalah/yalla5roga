import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';
import 'package:yalla_5roga/features/outings/domain/entities/group_place_suggestion.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_vote_widget.dart';

/// Card for one group place-suggestion vote.
class SuggestedPlaceCard extends StatelessWidget {
  const SuggestedPlaceCard({super.key, required this.suggestion});

  final GroupPlaceSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outings = context.watch<OutingsProvider>();
    final outing = outings.findById(suggestion.outingId);
    final endsAt = outings.voteEndsAt(suggestion.outingId);
    final voted = outings.hasVoted(suggestion.outingId);

    return AppCard(
      onTap: outing == null
          ? null
          : () => Get.to(() => EventPage(event: outing)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconCircle(
                icon: Icons.place_outlined,
                background: AppColors.amber100,
                foreground: AppColors.amber700,
              ),
              12.gapW,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.sp,
                      ),
                    ),
                    Text(
                      l10n.suggestedBy(suggestion.createdBy),
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: l10n.placesCount(suggestion.places.length),
                color: AppColors.brand50,
                textColor: AppColors.brand600,
              ),
            ],
          ),
          10.gapH,
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final place in suggestion.places)
                AppBadge(
                  label: place.name,
                  color: context.palette.surfaceMuted,
                  textColor: context.palette.textSecondary,
                ),
            ],
          ),
          10.gapH,
          Row(
            children: [
              if (endsAt != null)
                Expanded(child: VoteCountdownText(endsAt: endsAt)),
              AppBadge(
                label: voted ? l10n.youVoted : l10n.needsYourVote,
                color: voted ? AppColors.emerald50 : AppColors.amber100,
                textColor: voted ? const Color(0xFF059669) : AppColors.amber700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
