import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';

class CreateOutingStepHeader extends StatelessWidget {
  const CreateOutingStepHeader({super.key, required this.form});

  final CreateOutingProvider form;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [l10n.theBasics, l10n.chooseLocation, l10n.reviewOuting];
    final headlines = [l10n.whatAreWeDoing, l10n.pickAPlace, l10n.reviewOuting];
    final bodies = [
      l10n.addEssentials,
      l10n.chooseLocationNext,
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
                  duration: const Duration(milliseconds: 200),
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? (i == step ? AppColors.brand600 : AppColors.brand200)
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
                color: AppColors.brand600,
                fontWeight: FontWeight.w800,
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
        Responsive.spaceLg.gapH,
        Text(
          titles[step].toUpperCase(),
          style: TextStyle(
            color: AppColors.brand600,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        Text(
          headlines[step],
          style: TextStyle(
            fontSize: Responsive.fontLg,
            fontWeight: FontWeight.w800,
          ),
        ),
        Responsive.spaceXs.gapH,
        Text(
          bodies[step],
          style: TextStyle(color: context.palette.textMuted, fontSize: 12.sp),
        ),
        Responsive.spaceLg.gapH,
      ],
    );
  }
}
