import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/place_card.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/entities/meetup_results.dart';
import 'meetup_preference_chips.dart';

class MeetupRecommendationCard extends StatelessWidget {
  const MeetupRecommendationCard({
    super.key,
    required this.recommendation,
    required this.selected,
    required this.onFocus,
    this.onDetails,
    this.onRoutePreview,
    this.onCreateOuting,
    this.selectionMode = false,
  });

  final MeetupRecommendation recommendation;
  final bool selected;
  final VoidCallback onFocus;
  final VoidCallback? onDetails, onCreateOuting, onRoutePreview;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final row = recommendation;
    final l10n = context.l10n;
    final rating = row.averageRating;
    final price = row.budgetLevel == BudgetLevel.unknown
        ? l10n.meetupUnknownPrice
        : '${budgetSymbol(row.budgetLevel)}  ${budgetLabel(l10n, row.budgetLevel)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        PlaceCard.option(
          title: '${l10n.n(row.rank)} · ${row.place.localizedName(l10n)}',
          subtitle: row.place.branchLabel,
          selected: selected,
          onTap: onFocus,
          leading: PlaceCoverImage.fromSuggested(
            place: row.place,
            width: 54,
            height: 54,
            radius: 10,
          ),
          metadata: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rating == null || row.ratingCount == 0
                    ? l10n.meetupNoPlaceRatings
                    : l10n.meetupPlaceRatingSummary(rating, row.ratingCount),
              ),
              Text(price),
              TravelStatisticsWidget(recommendation: row),
              RecommendationExplanationWidget(codes: row.explanationCodes),
            ],
          ),
        ),
        OutlinedButton(onPressed: onDetails, child: Text(l10n.meetupViewPlace)),
        if (onRoutePreview != null)
          OutlinedButton(
            onPressed: onRoutePreview,
            child: Text(l10n.routePreviewTitle),
          ),
        FilledButton(
          onPressed: onCreateOuting,
          child: Text(selectionMode ? l10n.meetupUseVenue : l10n.creationTitle),
        ),
      ],
    );
  }
}

class TravelStatisticsWidget extends StatelessWidget {
  const TravelStatisticsWidget({super.key, required this.recommendation});
  final MeetupRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      if (recommendation.averageDurationMinutes case final minutes?)
        l10n.meetupAverageTravel(minutes),
      if (recommendation.matchScore case final score?)
        l10n.meetupMatchScore(score.round()),
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [for (final label in labels) Chip(label: Text(label))],
    );
  }
}

class RecommendationExplanationWidget extends StatelessWidget {
  const RecommendationExplanationWidget({super.key, required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final labels = codes
        .map(context.l10n.meetupRecommendationExplanation)
        .nonNulls;
    if (labels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final label in labels) Text(label, style: context.texts.bodySmall),
      ],
    );
  }
}
