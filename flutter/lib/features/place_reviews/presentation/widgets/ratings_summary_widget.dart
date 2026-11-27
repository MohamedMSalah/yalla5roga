import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/place_rating_statistics.dart';
import '../providers/place_rating_updates.dart';

class RatingsSummaryWidget extends StatelessWidget {
  const RatingsSummaryWidget({
    super.key,
    required this.placeId,
    required this.statistics,
    this.compact = false,
    this.onPhoto = false,
  });

  final String placeId;
  final PlaceRatingStatistics? statistics;
  final bool compact, onPhoto;

  @override
  Widget build(BuildContext context) {
    if (placeId.isEmpty || placeId.startsWith('private:')) {
      return const SizedBox.shrink();
    }
    final value = context.select<PlaceRatingUpdates?, PlaceRatingStatistics?>(
      (updates) => updates?.forPlace(placeId, statistics) ?? statistics,
    );
    if (value == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final color = onPhoto ? Colors.white : context.palette.textPrimary;
    final average = value.averageRating;
    if (average == null || value.ratingCount == 0) {
      return Text(
        l10n.placeNotRatedYet,
        style: (compact ? context.texts.labelSmall : context.texts.titleMedium)
            ?.copyWith(color: color),
      );
    }

    final rating = l10n.digits(average.toStringAsFixed(1));
    final count = l10n.n(value.ratingCount);
    return Semantics(
      label: l10n.placeRatingSummary(rating, count),
      excludeSemantics: true,
      child: Wrap(
        spacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.star_rounded,
            size: compact ? 16 : 26,
            color: onPhoto ? Colors.white : context.palette.brandStrong,
          ),
          Text(
            rating,
            style:
                (compact
                        ? context.texts.labelMedium
                        : context.texts.headlineSmall)
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          Text(
            compact ? '($count)' : l10n.placeRatingCount(value.ratingCount),
            style: context.texts.bodySmall?.copyWith(
              color: onPhoto ? color : context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
