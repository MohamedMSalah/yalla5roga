import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/active_vote_tile.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Active voting list for a single group's details page.
class GroupVotingList extends StatelessWidget {
  const GroupVotingList({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final votes = context.watch<OutingsProvider>().activeVotesForGroup(
      group.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.activeVoting,
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: votes.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == votes.length - 1 ? 0 : Responsive.spaceSm,
                ),
                child: ActiveVoteTile(outing: votes[index]),
              );
            },
          ),
      ],
    );
  }
}
