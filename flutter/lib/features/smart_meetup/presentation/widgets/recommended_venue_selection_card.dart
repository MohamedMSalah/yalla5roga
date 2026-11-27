import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';

import '../../domain/entities/meetup_results.dart';

class RecommendedVenueSelectionCard extends StatelessWidget {
  const RecommendedVenueSelectionCard({
    super.key,
    required this.recommendation,
    required this.selected,
    required this.onChanged,
  });

  final MeetupRecommendation recommendation;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final place = recommendation.place;
    final l10n = context.l10n;
    final subtitle = [
      place.branchLabel,
      if (recommendation.averageRating case final rating?)
        l10n.meetupPlaceRatingSummary(rating, recommendation.ratingCount),
    ].where((text) => text.isNotEmpty).join(' · ');
    return CheckboxListTile(
      value: selected,
      secondary: PlaceCoverImage.fromSuggested(
        place: place,
        width: 48,
        height: 48,
        radius: 8,
      ),
      title: Text(place.localizedName(l10n)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onChanged: onChanged,
    );
  }
}
