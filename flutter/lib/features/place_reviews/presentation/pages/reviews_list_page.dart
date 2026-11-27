import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

import '../../domain/entities/place_rating_statistics.dart';
import '../../domain/entities/place_review.dart';
import '../../domain/repositories/place_reviews_repository.dart';
import '../providers/place_rating_updates.dart';
import '../providers/place_reviews_provider.dart';
import '../widgets/rating_distribution_widget.dart';
import '../widgets/rating_stars_widget.dart';
import '../widgets/ratings_summary_widget.dart';
import '../widgets/report_review_dialog.dart';
import '../widgets/review_card.dart';
import '../widgets/submit_review_bottom_sheet.dart';

class ReviewsListPage extends StatelessWidget {
  const ReviewsListPage({
    super.key,
    required this.placeId,
    required this.acceptsRatings,
    this.initialStatistics,
    this.embedded = false,
  });

  final String placeId;
  final PlaceRatingStatistics? initialStatistics;
  final bool acceptsRatings, embedded;

  @override
  Widget build(BuildContext context) {
    final owner = context.select((AuthProvider auth) => auth.user?.id);
    final canLoad =
        owner != null && placeId.isNotEmpty && !placeId.startsWith('private:');
    final body = !canLoad
        ? ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [Text(context.l10n.placeReviewsUnavailable)],
          )
        : ChangeNotifierProvider(
            key: ValueKey((owner, placeId)),
            create: (context) => PlaceReviewsProvider(
              context.read<PlaceReviewsRepository>(),
              context.read<PlaceRatingUpdates>(),
              placeId: placeId,
            )..load(),
            child: _ReviewsList(
              acceptsRatings: acceptsRatings,
              initialStatistics: initialStatistics,
            ),
          );
    if (embedded) return body;
    return Scaffold(
      appBar: AppPageBar(title: context.l10n.placeReviews),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: body,
        ),
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.acceptsRatings, this.initialStatistics});

  final PlaceRatingStatistics? initialStatistics;
  final bool acceptsRatings;

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(title),
            ),
          ],
        ),
      ) ??
      false;

  void _feedback(BuildContext context, Failure? failure, {String? success}) {
    if (!context.mounted) return;
    final text = failure == null
        ? success
        : FailureMessageMapper.localize(failure, context.l10n);
    if (text != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _delete(
    BuildContext context,
    PlaceReviewsProvider provider,
  ) async {
    final l10n = context.l10n;
    if (await _confirm(
          context,
          l10n.placeDeleteRating,
          l10n.placeDeleteRatingPrompt,
        ) &&
        context.mounted) {
      final result = await provider.remove();
      if (context.mounted) _feedback(context, result);
    }
  }

  Future<void> _act(
    BuildContext context,
    PlaceReviewsProvider provider,
    PlaceReview review,
    ReviewAction action,
  ) async {
    final l10n = context.l10n;
    switch (action) {
      case ReviewAction.report:
        final sent = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              ReportReviewDialog(provider: provider, review: review),
        );
        if (context.mounted && sent == true) {
          _feedback(context, null, success: l10n.placeReportSent);
        }
      case ReviewAction.block:
        if (await _confirm(
              context,
              l10n.placeBlockAuthor,
              l10n.placeBlockAuthorPrompt,
            ) &&
            context.mounted) {
          final result = await provider.block(review);
          if (context.mounted) _feedback(context, result);
        }
    }
  }

  void _manageBlocks(BuildContext context, PlaceReviewsProvider provider) {
    provider.loadBlocks();
    showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const _BlockedAuthorsDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaceReviewsProvider>();
    final l10n = context.l10n;
    final mine = provider.mine;
    final active = !provider.loading && !provider.mutating;
    final stats = context.select<PlaceRatingUpdates, PlaceRatingStatistics?>(
      (updates) => updates.forPlace(
        provider.placeId,
        provider.statistics ?? initialStatistics,
      ),
    );
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        RatingsSummaryWidget(placeId: provider.placeId, statistics: stats),
        if (stats != null) RatingDistributionWidget(statistics: stats),
        if (provider.ratingFailure case final error?)
          Text(FailureMessageMapper.localize(error, l10n)),
        if (mine != null) ...[
          Text(l10n.placeYourRating, style: context.texts.titleMedium),
          RatingStarsWidget(rating: mine.rating),
          if (mine.hidden) Text(l10n.placeHiddenRating),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (acceptsRatings)
                OutlinedButton(
                  onPressed: active
                      ? () => SubmitReviewBottomSheet.show(context, provider)
                      : null,
                  child: Text(l10n.placeEditRating),
                ),
              TextButton(
                onPressed: active ? () => _delete(context, provider) : null,
                child: Text(l10n.placeDeleteRating),
              ),
            ],
          ),
        ] else if (acceptsRatings)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: active && provider.ratingFailure == null
                  ? () => SubmitReviewBottomSheet.show(context, provider)
                  : null,
              icon: const Icon(Icons.star_outline_rounded),
              label: Text(l10n.placeRateThis),
            ),
          ),
        if (!acceptsRatings) Text(l10n.placeRatingsClosed),
        const Divider(),
        Wrap(
          spacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.placeWrittenReviews, style: context.texts.titleMedium),
            TextButton(
              onPressed: active ? () => _manageBlocks(context, provider) : null,
              child: Text(l10n.placeBlockedAuthors),
            ),
          ],
        ),
        if (provider.loading || provider.mutating)
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: CircularProgressIndicator(),
          )
        else if (provider.reviews.isEmpty && provider.reviewsFailure == null)
          Text(l10n.placeNoWrittenReviews),
      ],
    );

    final itemCount = provider.reviews.length;
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.builder(
        key: PageStorageKey('place-reviews-${provider.placeId}'),
        padding: const EdgeInsets.all(AppSpacing.xl),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount + 2,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          if (index <= itemCount) {
            final review = provider.reviews[index - 1];
            return Column(
              children: [
                ReviewCard(
                  key: ValueKey(review.id),
                  review: review,
                  onAction: active
                      ? (action) => _act(context, provider, review, action)
                      : null,
                ),
                const Divider(),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.reviewsFailure case final error?)
                Text(FailureMessageMapper.localize(error, l10n)),
              if (provider.reviewsFailure != null ||
                  provider.ratingFailure != null)
                TextButton(
                  onPressed: active ? provider.load : null,
                  child: Text(l10n.catalogRetry),
                )
              else if (provider.hasMore)
                TextButton(
                  onPressed: active && !provider.loadingPage
                      ? provider.loadMore
                      : null,
                  child: Text(
                    provider.loadingPage
                        ? l10n.placeLoadingReviews
                        : l10n.placeMoreReviews,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BlockedAuthorsDialog extends StatelessWidget {
  const _BlockedAuthorsDialog();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaceReviewsProvider>();
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.placeBlockedAuthors),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final author in provider.blockedAuthors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(author.name),
              subtitle: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: provider.mutating || provider.loadingBlocks
                      ? null
                      : () async {
                          final failure = await provider.unblock(author.id);
                          if (context.mounted && failure != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  FailureMessageMapper.localize(failure, l10n),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(l10n.placeUnblockAuthor),
                ),
              ),
            ),
          if (provider.loadingBlocks)
            const Center(child: CircularProgressIndicator())
          else if (provider.blocksFailure case final error?) ...[
            Text(FailureMessageMapper.localize(error, l10n)),
            TextButton(
              onPressed: provider.loadBlocks,
              child: Text(l10n.catalogRetry),
            ),
          ] else if (provider.blockedAuthors.isEmpty)
            Text(l10n.placeNoBlockedAuthors)
          else if (provider.hasMoreBlocks)
            TextButton(
              onPressed: () => provider.loadBlocks(more: true),
              child: Text(l10n.placeMoreReviewAuthors),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
