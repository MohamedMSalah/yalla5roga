import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';

class OnboardingContent extends StatelessWidget {
  const OnboardingContent({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [
      l10n.onboardingGroups,
      l10n.onboardingPlans,
      l10n.onboardingDiscover,
    ];
    final descriptions = [
      l10n.onboardingGroupsBody,
      l10n.onboardingPlansBody,
      l10n.onboardingDiscoverBody,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: PlanningCover(
            url: '',
            art: step == 0 ? PlanningCoverArt.group : PlanningCoverArt.outing,
            width: double.infinity,
            height: 200.h,
            radius: 16,
          ),
        ),
        Responsive.spaceXl.gapH,
        Text(titles[step], style: context.texts.headlineMedium),
        Responsive.spaceMd.gapH,
        Text(
          descriptions[step],
          style: context.texts.bodyLarge?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
      ],
    );
  }
}
