import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/outings/domain/entities/voting_deadline.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';

/// Renders provider-owned duration selection and schedule validation.
class VotingDeadlineSelector extends StatelessWidget {
  const VotingDeadlineSelector({super.key, required this.form});
  final CreateOutingProvider form;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = form.deadlineUnit == VotingDeadlineUnit.days;
    final durations = days
        ? [for (final value in VotingDeadlinePolicy.dayPresets) value * 24]
        : [
            ...VotingDeadlinePolicy.hourPresets,
            if (!VotingDeadlinePolicy.hourPresets.contains(
              form.voteDeadlineHours,
            ))
              form.voteDeadlineHours,
          ];
    final error = form.votingDeadlineError(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.votingDeadlineTitle,
            style: context.texts.titleMedium,
          ),
        ),
        Responsive.spaceSm.gapH,
        SegmentedButton<VotingDeadlineUnit>(
          segments: [
            ButtonSegment(
              value: VotingDeadlineUnit.hours,
              label: Text(l10n.votingDeadlineHoursMode),
            ),
            ButtonSegment(
              value: VotingDeadlineUnit.days,
              label: Text(l10n.votingDeadlineDaysMode),
            ),
          ],
          selected: {form.deadlineUnit},
          onSelectionChanged: (value) => form.setDeadlineUnit(value.single),
          showSelectedIcon: false,
        ),
        Responsive.spaceSm.gapH,
        Wrap(
          spacing: Responsive.spaceSm,
          runSpacing: Responsive.spaceXs,
          children: [
            for (final hours in durations)
              ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text(
                  days
                      ? l10n.votingDurationDays(hours ~/ 24)
                      : l10n.votingDurationHours(hours),
                ),
                selected: form.voteDeadlineHours == hours,
                onSelected: form.canSelectDeadlineHours(hours)
                    ? (_) => form.setVoteDeadlineHours(hours)
                    : null,
              ),
          ],
        ),
        Responsive.spaceSm.gapH,
        Text(
          l10n.votingDeadlineSummary(form.previewVotingDeadline),
          style: context.texts.bodyMedium,
        ),
        Responsive.spaceXs.gapH,
        Text(
          l10n.votingDeadlineFromSubmission,
          style: context.texts.bodySmall?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        if (error != null) ...[
          Responsive.spaceXs.gapH,
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
