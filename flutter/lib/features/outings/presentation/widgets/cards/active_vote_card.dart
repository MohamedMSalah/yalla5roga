import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/outing_card.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/outing_l10n.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_vote_widget.dart';

class ActiveVoteCard extends StatelessWidget {
  const ActiveVoteCard({super.key, required this.outing, this.width});
  final Outing outing;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<OutingsProvider>();
    final endsAt = store.voteEndsAt(outing.id) ?? outing.voteEndsAt;
    final group = context.watch<GroupsProvider>().findById(
      outing.groupId ?? '',
    );
    final options = store.optionsFor(outing.id);
    final voted = store.votedCountFor(outing.id);
    final eligible = store.eligibleVoterCountFor(outing.id);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutingCard(
            title: outing.title,
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (options.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final option in options)
                        AppBadge(
                          label: option.label,
                          color: context.palette.surfaceSoft,
                          textColor: context.palette.textPrimary,
                        ),
                    ],
                  ),
                if (endsAt != null) ...[
                  Responsive.spaceSm.gapH,
                  VoteCountdownText(
                    endsAt: endsAt,
                    isClosed: store.isVoteFinalized(outing.id),
                  ),
                ],
                if (eligible > 0) ...[
                  Responsive.spaceSm.gapH,
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (voted / eligible).clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: context.palette.surfaceSoft,
                            semanticsLabel: context.l10n.votedCount(
                              voted,
                              eligible,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          context.l10n.votedCount(voted, eligible),
                          style: context.texts.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            subtitle: [
              if (group != null) group.name,
              outing.localizedWhen(context.l10n),
            ].join(' · '),
            cover: PlanningCover(
              url: outing.image,
              art: outing.occasion.coverArt,
              width: 80.w,
              height: 86.w,
            ),
            statusLabel: store.hasVoted(outing.id)
                ? context.l10n.youVoted
                : context.l10n.voting,
            onTap: () => Get.to(
              () => EventPage(
                event: outing,
                initialSection: OutingDetailsSection.placeVoting,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
