import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/place_rating_statistics.dart';

class RatingDistributionWidget extends StatelessWidget {
  const RatingDistributionWidget({super.key, required this.statistics});

  final PlaceRatingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      spacing: AppSpacing.sm,
      children: [
        for (var stars = 5; stars > 0; stars--)
          Semantics(
            label: l10n.placeRatingDistributionEntry(
              stars,
              statistics.distribution.countFor(stars),
            ),
            excludeSemantics: true,
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                Text(l10n.n(stars), style: context.texts.labelMedium),
                Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: context.palette.brandStrong,
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: statistics.ratingCount == 0
                        ? 0
                        : statistics.distribution.countFor(stars) /
                              statistics.ratingCount,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                Text(
                  l10n.n(statistics.distribution.countFor(stars)),
                  style: context.texts.labelMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
