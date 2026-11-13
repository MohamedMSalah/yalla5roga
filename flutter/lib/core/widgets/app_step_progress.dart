import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppStepProgress extends StatelessWidget {
  const AppStepProgress({
    super.key,
    required this.step,
    required this.total,
    required this.label,
  });
  final int step;
  final int total;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    value: label,
    child: Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) Responsive.spaceXs.gapW,
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.standard),
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: i <= step
                    ? context.colors.primary
                    : context.palette.border,
              ),
            ),
          ),
        ],
        Responsive.spaceSm.gapW,
        Text(label, style: context.texts.labelMedium),
      ],
    ),
  );
}
