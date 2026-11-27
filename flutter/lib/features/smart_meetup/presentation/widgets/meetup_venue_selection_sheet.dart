import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/app_offline_indicator.dart';

import '../../domain/entities/meetup_results.dart';
import '../providers/meetup_results_provider.dart';
import 'meetup_result_states.dart';
import 'recommended_venue_selection_card.dart';

class MeetupVenueSelectionSheet extends StatefulWidget {
  const MeetupVenueSelectionSheet({
    super.key,
    required this.provider,
    required this.calculationId,
    required this.recommendations,
    required this.limit,
  });

  final MeetupResultsProvider provider;
  final String calculationId;
  final List<MeetupRecommendation> recommendations;
  final int limit;

  static Future<Set<String>?> show(
    BuildContext context, {
    required MeetupResultsProvider provider,
    required String calculationId,
    required List<MeetupRecommendation> recommendations,
    required int limit,
  }) => AppBottomSheet.show(
    context: context,
    builder: (_) => MeetupVenueSelectionSheet(
      provider: provider,
      calculationId: calculationId,
      recommendations: recommendations,
      limit: limit,
    ),
  );

  @override
  State<MeetupVenueSelectionSheet> createState() =>
      _MeetupVenueSelectionSheetState();
}

class _MeetupVenueSelectionSheetState extends State<MeetupVenueSelectionSheet> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      if (widget.provider.offline) {
        return const AppOfflineIndicator(isOffline: true);
      }
      final calculation = widget.provider.result?.calculation;
      if (!widget.provider.canConsume ||
          calculation?.id != widget.calculationId) {
        return const StaleResultsBanner();
      }
      final l10n = context.l10n;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.meetupSelectVotingPlaces, style: context.texts.titleLarge),
          Text(l10n.meetupVotingSelectionHint),
          for (final recommendation in widget.recommendations)
            RecommendedVenueSelectionCard(
              recommendation: recommendation,
              selected: _selected.contains(recommendation.place.id),
              onChanged:
                  _selected.length < widget.limit ||
                      _selected.contains(recommendation.place.id)
                  ? (checked) => setState(() {
                      final id = recommendation.place.id;
                      if (checked == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    })
                  : null,
            ),
          FilledButton(
            onPressed: _selected.length < 2
                ? null
                : () => Navigator.pop(context, Set.of(_selected)),
            child: Text(l10n.meetupUseVenues),
          ),
        ],
      );
    },
  );
}
