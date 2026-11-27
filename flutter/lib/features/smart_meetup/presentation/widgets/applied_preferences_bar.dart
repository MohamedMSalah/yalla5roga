import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/meetup_preferences.dart';
import 'meetup_preference_chips.dart';

class AppliedPreferencesBar extends StatelessWidget {
  const AppliedPreferencesBar({
    super.key,
    required this.preferences,
    this.categories = const [],
  });

  final MeetupPreferences preferences;
  final List<MeetupCategoryOption> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names = {
      for (final option in categories)
        option.id: option.label(l10n.locale.languageCode),
    };
    final unknown = preferences.categoryIds
        .where((id) => !names.containsKey(id))
        .length;
    final labels = [
      fairnessLabel(l10n, preferences.travelFairnessMode),
      for (final id in preferences.categoryIds) ?names[id],
      if (unknown > 0) l10n.meetupSelectedCategories(unknown),
      for (final level in MeetupPreferences.selectableBudgets)
        if (preferences.budgetLevels.contains(level))
          '${budgetSymbol(level)}  ${budgetLabel(l10n, level)}',
      if (preferences.minimumRating != null)
        ratingLabel(l10n, preferences.minimumRating),
      if (preferences.maximumTravelDurationSeconds != null)
        travelTimeLabel(l10n, preferences.maximumTravelDurationSeconds),
      if (preferences.plannedMeetupAt?.toLocal() case final time?)
        '${l10n.formatDate(time)} · ${l10n.formatTime(time)}',
      if (preferences.requireOpenAtMeetupTime) l10n.meetupOpenAtTime,
      for (final priority in OptimizationPriority.values)
        if (preferences.additionalPriorities.contains(priority))
          priorityLabel(l10n, priority),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [for (final label in labels) Chip(label: Text(label))],
    );
  }
}
