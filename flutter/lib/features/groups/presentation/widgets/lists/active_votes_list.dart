import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/active_vote_card.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Horizontal active-votes list for the Groups screen.
class ActiveVotesList extends StatelessWidget {
  const ActiveVotesList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final votes = context.watch<OutingsProvider>().activeVotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.activeVotes,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        Responsive.spaceSm.gapH,
        if (votes.isEmpty)
          AppEmptyState(
            icon: Icons.how_to_vote_outlined,
            message: l10n.noActiveVotes,
            compact: true,
          )
        else
          SizedBox(
            height: Responsive.voteCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: votes.length,
              separatorBuilder: (_, _) => Responsive.spaceMd.gapW,
              itemBuilder: (context, index) {
                return ActiveVoteCard(outing: votes[index]);
              },
            ),
          ),
      ],
    );
  }
}
