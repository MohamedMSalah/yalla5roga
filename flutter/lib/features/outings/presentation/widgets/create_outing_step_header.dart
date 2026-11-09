import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
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
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) 6.gapW,
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.standard),
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? (i == step
                              ? context.colors.primary
                              : context.palette.brandSoftBorder)
                        : context.palette.border,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
            ],
            Responsive.spaceSm.gapW,
            Text(
              l10n.stepOf(step + 1, 3),
              style: TextStyle(
                color: context.palette.brandStrong,
                fontWeight: FontWeight.w800,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
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
