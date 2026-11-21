import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppStepProgress extends StatelessWidget {
  const AppStepProgress({
    super.key,
    required this.step,
    required this.total,
    required this.label,
    this.labels,
  });
  final int step;
  final int total;
  final String label;
  final List<String>? labels;
  @override
  Widget build(BuildContext context) {
    if (labels case final titles?) return _labeled(context, titles);
    return Semantics(
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

  Widget _labeled(BuildContext context, List<String> titles) => Semantics(
    value: label,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / titles.length;
        return Stack(
          children: [
            PositionedDirectional(
              start: width / 2,
              end: width / 2,
              top: 14,
              child: Row(
                children: [
                  for (var i = 1; i < titles.length; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppMotion.of(context, AppMotion.standard),
                        height: 2,
                        color: i <= step
                            ? context.palette.brand
                            : context.palette.border,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, title) in titles.indexed)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= step
                                ? context.palette.chipActive
                                : context.palette.surfaceMuted,
                          ),
                          child: i < step
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: context.palette.chipActiveText,
                                )
                              : Text(
                                  context.l10n.n(i + 1),
                                  style: context.texts.labelMedium?.copyWith(
                                    color: i == step
                                        ? context.palette.chipActiveText
                                        : context.palette.textSecondary,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: context.texts.labelMedium?.copyWith(
                            color: i == step
                                ? context.palette.brandStrong
                                : context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
