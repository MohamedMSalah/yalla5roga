import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/meetup_preferences.dart';

String budgetLabel(L10n l10n, BudgetLevel level) => switch (level) {
  BudgetLevel.affordable => l10n.meetupAffordable,
  BudgetLevel.moderate => l10n.meetupModerate,
  BudgetLevel.expensive => l10n.meetupExpensive,
  BudgetLevel.unknown => throw ArgumentError.value(level),
};

String budgetSymbol(BudgetLevel level) => switch (level) {
  BudgetLevel.affordable => r'$',
  BudgetLevel.moderate => r'$$',
  BudgetLevel.expensive => r'$$$',
  BudgetLevel.unknown => throw ArgumentError.value(level),
};

String ratingLabel(L10n l10n, double? rating) => rating == null
    ? l10n.meetupAny
    : l10n.meetupRatingThreshold(rating.toStringAsFixed(1));

String fairnessLabel(L10n l10n, TravelFairnessMode mode) => switch (mode) {
  TravelFairnessMode.balanced => l10n.meetupBalanced,
  TravelFairnessMode.equalTravel => l10n.meetupEqualTravel,
  TravelFairnessMode.fastestOverall => l10n.meetupFastestOverall,
};

String fairnessHint(L10n l10n, TravelFairnessMode mode) => switch (mode) {
  TravelFairnessMode.balanced => l10n.meetupBalancedHint,
  TravelFairnessMode.equalTravel => l10n.meetupEqualTravelHint,
  TravelFairnessMode.fastestOverall => l10n.meetupFastestOverallHint,
};

String travelTimeLabel(L10n l10n, int? seconds) =>
    seconds == null ? l10n.meetupAny : l10n.meetupTravelMinutes(seconds ~/ 60);

String priorityLabel(L10n l10n, OptimizationPriority priority) =>
    switch (priority) {
      OptimizationPriority.topRated => l10n.meetupTopRated,
      OptimizationPriority.budgetFriendly => l10n.meetupBudgetFriendly,
      OptimizationPriority.shortestDistance => l10n.meetupShortestDistance,
    };

class BudgetLevelChip extends StatelessWidget {
  const BudgetLevelChip({
    super.key,
    required this.level,
    required this.selected,
    required this.onSelected,
  });

  final BudgetLevel level;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text('${budgetSymbol(level)}  ${budgetLabel(context.l10n, level)}'),
    selected: selected,
    onSelected: onSelected,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

class MinimumRatingChip extends StatelessWidget {
  const MinimumRatingChip({
    super.key,
    required this.rating,
    required this.selected,
    required this.onSelected,
  });

  final double? rating;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(ratingLabel(context.l10n, rating)),
    selected: selected,
    onSelected: onSelected == null ? null : (_) => onSelected!(),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

class TravelFairnessSelector extends StatelessWidget {
  const TravelFairnessSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TravelFairnessMode selected;
  final ValueChanged<TravelFairnessMode>? onChanged;

  @override
  Widget build(BuildContext context) => RadioGroup<TravelFairnessMode>(
    groupValue: selected,
    onChanged: (value) {
      if (value != null) onChanged?.call(value);
    },
    child: Column(
      children: [
        for (final mode in TravelFairnessMode.values)
          RadioListTile(
            contentPadding: EdgeInsets.zero,
            value: mode,
            enabled: onChanged != null,
            title: Text(fairnessLabel(context.l10n, mode)),
            subtitle: Text(fairnessHint(context.l10n, mode)),
          ),
      ],
    ),
  );
}

class MaximumTravelTimeChip extends StatelessWidget {
  const MaximumTravelTimeChip({
    super.key,
    required this.seconds,
    required this.selected,
    required this.onSelected,
  });

  final int? seconds;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(travelTimeLabel(context.l10n, seconds)),
    selected: selected,
    onSelected: onSelected == null ? null : (_) => onSelected!(),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

class OptimizationPriorityChip extends StatelessWidget {
  const OptimizationPriorityChip({
    super.key,
    required this.priority,
    required this.selected,
    required this.onSelected,
  });

  final OptimizationPriority priority;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(priorityLabel(context.l10n, priority)),
    selected: selected,
    onSelected: onSelected,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}
