import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/place_review.dart';
import 'rating_stars_widget.dart';

enum ReviewAction { report, block }

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.onAction});

  final PlaceReview review;
  final ValueChanged<ReviewAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerName, style: context.texts.titleSmall),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(review.createdAt.toLocal()),
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!review.isMine && onAction != null)
                PopupMenuButton<ReviewAction>(
                  tooltip: l10n.placeReviewActions,
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: ReviewAction.report,
                      child: Text(l10n.placeReportReview),
                    ),
                    PopupMenuItem(
                      value: ReviewAction.block,
                      child: Text(l10n.placeBlockAuthor),
                    ),
                  ],
                ),
            ],
          ),
          RatingStarsWidget(rating: review.rating),
          if (review.text case final text?) Text(text),
        ],
      ),
    );
  }
}
