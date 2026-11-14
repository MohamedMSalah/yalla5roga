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
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutingCard(
            title: outing.title,
            footer: endsAt == null
                ? null
                : VoteCountdownText(
                    endsAt: endsAt,
                    isClosed: store.isVoteFinalized(outing.id),
                  ),
            subtitle: [
              if (group != null) group.name,
              outing.localizedWhen(context.l10n),
              context.l10n.votedCount(
                store.votedCountFor(outing.id),
                store.eligibleVoterCountFor(outing.id),
              ),
            ].join(' · '),
            cover: PlanningCover(
              url: outing.image,
              art: outing.occasion.coverArt,
              width: 56.w,
              height: 56.w,
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
