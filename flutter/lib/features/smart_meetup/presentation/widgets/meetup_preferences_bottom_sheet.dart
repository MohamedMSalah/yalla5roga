import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../providers/smart_meetup_provider.dart';
import 'meetup_preference_chips.dart';

class MeetupPreferencesBottomSheet extends StatefulWidget {
  const MeetupPreferencesBottomSheet({
    super.key,
    required this.initial,
    required this.provider,
    required this.sessionId,
  });

  final MeetupPreferences initial;
  final SmartMeetupProvider provider;
  final String sessionId;

  @override
  State<MeetupPreferencesBottomSheet> createState() =>
      _MeetupPreferencesBottomSheetState();
}

class _MeetupPreferencesBottomSheetState
    extends State<MeetupPreferencesBottomSheet> {
  late MeetupPreferences _draft = widget.initial;
  bool _saving = false;
  bool _reset = false;
  String? _error;

  void _edit(MeetupPreferences preferences) => setState(() {
    _draft = preferences;
    _reset = false;
    _error = null;
  });

  void _resetDraft() => setState(() {
    _draft = const MeetupPreferences();
    _reset = true;
    _error = null;
  });

  Set<T> _toggle<T>(Set<T> values, T value, bool selected) {
    final next = {...values};
    if (selected) {
      next.add(value);
    } else {
      next.remove(value);
    }
    return next;
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = widget.provider;
    final saved = await provider.updatePreferences(
      widget.sessionId,
      _draft,
      reset: _reset,
    );
    if (!mounted) return;
    if (saved && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      if (!saved) {
        final failure = provider.failure;
        _error = failure == null
            ? context.l10n.errorUnexpected
            : FailureMessageMapper.localize(failure, context.l10n);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.meetupPreferences,
                style: context.texts.titleLarge,
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        _categories(),
        _section(l10n.meetupBudget, [
          for (final level in MeetupPreferences.selectableBudgets)
            BudgetLevelChip(
              level: level,
              selected: _draft.budgetLevels.contains(level),
              onSelected: _saving
                  ? null
                  : (selected) => _edit(
                      _draft.copyWith(
                        budgetLevels: _toggle(
                          _draft.budgetLevels,
                          level,
                          selected,
                        ),
                      ),
                    ),
            ),
        ], hint: l10n.meetupRelativeBudget),
        _section(l10n.meetupPlaceRating, [
          for (final rating in MeetupPreferences.minimumRatings)
            MinimumRatingChip(
              rating: rating,
              selected: _draft.minimumRating == rating,
              onSelected: _saving
                  ? null
                  : () => _edit(_draft.copyWith(minimumRating: rating)),
            ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.meetupTravelFairness, style: context.texts.titleMedium),
        TravelFairnessSelector(
          selected: _draft.travelFairnessMode,
          onChanged: _saving
              ? null
              : (mode) => _edit(_draft.copyWith(travelFairnessMode: mode)),
        ),
        _section(l10n.meetupMaximumTravelTime, [
          for (final seconds in MeetupPreferences.maximumTravelDurations)
            MaximumTravelTimeChip(
              seconds: seconds,
              selected: _draft.maximumTravelDurationSeconds == seconds,
              onSelected: _saving
                  ? null
                  : () => _edit(
                      _draft.copyWith(maximumTravelDurationSeconds: seconds),
                    ),
            ),
        ]),
        _section(l10n.meetupAdditionalPriorities, [
          for (final priority in OptimizationPriority.values)
            OptimizationPriorityChip(
              priority: priority,
              selected: _draft.additionalPriorities.contains(priority),
              onSelected: _saving
                  ? null
                  : (selected) => _edit(
                      _draft.copyWith(
                        additionalPriorities: _toggle(
                          _draft.additionalPriorities,
                          priority,
                          selected,
                        ),
                      ),
                    ),
            ),
        ]),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: _saving ? null : _resetDraft,
              child: Text(l10n.meetupResetPreferences),
            ),
            FilledButton(
              onPressed: _saving ? null : _apply,
              child: _saving
                  ? const SizedBox.square(
                      dimension: AppSizes.icon,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.meetupApplyPreferences),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categories() {
    final l10n = context.l10n;
    final provider = widget.provider.preferences;
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final categories = {
          for (final option
              in provider.categories ?? const <MeetupCategoryOption>[])
            option.id: option.label(l10n.locale.languageCode),
        };
        for (final id in _draft.categoryIds) {
          categories.putIfAbsent(id, () => l10n.meetupUnavailableCategory);
        }
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(
            l10n.meetupPlaceCategory,
            style: context.texts.titleMedium,
          ),
          subtitle: _draft.categoryIds.isEmpty
              ? null
              : Text(l10n.meetupSelectedCategories(_draft.categoryIds.length)),
          children: [
            if (provider.loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: CircularProgressIndicator(),
              ),
            if (provider.failure != null)
              TextButton.icon(
                onPressed: provider.loadCategories,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.catalogRetryCategories),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final entry in categories.entries)
                  FilterChip(
                    label: Text(entry.value),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.standard,
                    selected: _draft.categoryIds.contains(entry.key),
                    onSelected: _saving
                        ? null
                        : (selected) => _edit(
                            _draft.copyWith(
                              categoryIds: _toggle(
                                _draft.categoryIds,
                                entry.key,
                                selected,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _section(String title, List<Widget> chips, {String? hint}) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.texts.titleMedium),
        if (hint != null) Text(hint, style: context.texts.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.sm, children: chips),
      ],
    ),
  );
}
