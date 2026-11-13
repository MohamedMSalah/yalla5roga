import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/app_step_progress.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';

class CreateOutingStepHeader extends StatelessWidget {
  const CreateOutingStepHeader({super.key, required this.form});

  final CreateOutingProvider form;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final multi = form.multiPlaceMode;
    final headlines = [
      l10n.whatAreWeDoing,
      multi ? l10n.pickMultiplePlaces : l10n.pickAPlace,
      l10n.reviewOuting,
    ];
    final bodies = [
      l10n.addEssentials,
      multi ? l10n.suggestPlacesSheetHint : l10n.chooseLocationNext,
      l10n.almostThere,
    ];
    final step = form.step;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppStepProgress(step: step, total: 3, label: l10n.stepOf(step + 1, 3)),
        Responsive.spaceLg.gapH,
        Semantics(
          header: true,
          child: Text(
            headlines[step],
            style: context.texts.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Responsive.spaceXs.gapH,
        Text(
          bodies[step],
          style: context.texts.bodyMedium?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        Responsive.spaceLg.gapH,
      ],
    );
  }
}
