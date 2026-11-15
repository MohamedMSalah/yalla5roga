import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_vote.dart';

import 'voting_place_list.dart';

class TieResultsSection extends StatelessWidget {
  const TieResultsSection({
    super.key,
    required this.options,
    required this.round,
    required this.isCreator,
    required this.busy,
    required this.onRandom,
    required this.onRevote,
  });
  final List<VoteOption> options;
  final int round;
  final bool isCreator, busy;
  final VoidCallback onRandom, onRevote;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.locationTieTitle, style: context.texts.titleMedium),
        Responsive.spaceSm.gapH,
        Text(l.votingRound(round), style: context.texts.bodySmall),
        Responsive.spaceSm.gapH,
        Text(
          options.every((o) => o.votes == 0)
              ? l.noLocationVotesExplanation
              : l.locationTieExplanation,
        ),
        Responsive.spaceMd.gapH,
        OutingVoteOptions(
          options: options,
          selectedIndexes: const {},
          onSelected: (_) {},
          enabled: false,
        ),
        Responsive.spaceMd.gapH,
        if (isCreator) ...[
          CustomButton(
            label: l.rollTheDice,
            icon: Icons.casino_outlined,
            isLoading: busy,
            onPressed: busy ? null : onRandom,
          ),
          Responsive.spaceSm.gapH,
          CustomButton(
            label: l.revote,
            icon: Icons.how_to_vote_outlined,
            onPressed: busy ? null : onRevote,
          ),
        ] else
          Text(l.waitingForOutingCreator, style: context.texts.bodyMedium),
      ],
    );
  }
}
