import 'dart:async';

import 'package:yalla_5roga/features/discover/presentation/widgets/place_branch_picker.dart';

import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/place_reviews/presentation/pages/reviews_list_page.dart';
import 'package:yalla_5roga/features/place_reviews/presentation/widgets/ratings_summary_widget.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart'
    show PlaceCatalogAttribution;
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/app_launcher.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/save_place_button.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';

class DiscoverPlaceDetailsPage extends StatefulWidget {
  const DiscoverPlaceDetailsPage({
    super.key,
    required this.placeId,
    this.coverHeroTag,
    this.coverUrl,
    this.initialPlace,
  });

  final String placeId;
  final SuggestedPlace? initialPlace;

  /// Hero tag of the card cover that opened this page. Only the gallery image
  /// that matches the tapped cover takes part in the flight.
  final String? coverHeroTag;

  /// Cover URL from the card (may differ from a live-API gallery[0]).
  final String? coverUrl;

  /// Builds a gallery that always contains the card cover when the URL is
  /// known. Live APIs often send a different first gallery photo than
  /// `coverImageUrl`.
  @visibleForTesting
  static ({List<DiscoverPlaceImage> gallery, int coverIndex}) heroGallery({
    required SuggestedPlace place,
    String? tappedCoverUrl,
  }) {
    final cover = (tappedCoverUrl ?? place.coverImageUrl).trim();
    final images = place.images.isNotEmpty
        ? List<DiscoverPlaceImage>.from(place.images)
        : [DiscoverPlaceImage(imageUrl: place.coverImageUrl)];
    if (cover.isEmpty) {
      return (gallery: images, coverIndex: -1);
    }
    final existing = images.indexWhere((image) => image.imageUrl == cover);
    if (existing >= 0) {
      return (gallery: images, coverIndex: existing);
    }
    return (
      gallery: [
        DiscoverPlaceImage(imageUrl: cover),
        ...images,
      ],
      coverIndex: 0,
    );
  }

  @override
  State<DiscoverPlaceDetailsPage> createState() => _DiscoverPlaceDetailsState();
}

class _DiscoverPlaceDetailsState extends State<DiscoverPlaceDetailsPage> {
  SuggestedPlace? _place;
  int _photoIndex = 0;
  bool _loading = true, _failed = false;
  StreamSubscription<void>? _changes;
  @override
  void initState() {
    super.initState();
    final provider = context.read<DiscoverProvider>();
    _place = widget.initialPlace ?? provider.findById(widget.placeId);
    _changes = provider.repository.catalogChanges.listen((_) => _load());
    unawaited(_load());
  }

  Future<void> _load() async {
    final result = await context.read<DiscoverProvider>().repository.getPlace(
      widget.placeId,
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold(
        (_) {
          _failed = true;
        },
        (place) {
          _failed = false;
          _place = place;
        },
      );
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final place = _place;
    if (place == null) {
      return Scaffold(
        appBar: AppPageBar(title: l10n.allPlaces),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : TextButton(onPressed: _load, child: Text(l10n.catalogRetry)),
        ),
      );
    }
    final laidOut = DiscoverPlaceDetailsPage.heroGallery(
      place: place,
      tappedCoverUrl: widget.coverUrl,
    );
    final gallery = laidOut.gallery;
    final coverIndex = laidOut.coverIndex;

    final surface = palette.surface;
    final tabs = TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.center,
      labelColor: palette.brandStrong,
      unselectedLabelColor: palette.textSecondary,
      indicatorColor: palette.brand,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorWeight: 3,
      tabs: [
        Tab(text: l10n.placeOverview),
        Tab(text: l10n.placeBranches),
        Tab(text: l10n.placeReviews),
      ],
    );
    return DefaultTabController(
      length: 3,
      animationDuration: AppMotion.of(context, AppMotion.standard),
      child: Scaffold(
        backgroundColor: surface,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: surface,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: (MediaQuery.sizeOf(context).height * .38)
                      .clamp(240.0, 400.0),
                  leading: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Material(
                      color: surface,
                      shape: const CircleBorder(),
                      child: const BackButton(),
                    ),
                  ),
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final collapsed =
                          constraints.maxHeight <=
                          MediaQuery.paddingOf(context).top +
                              kToolbarHeight +
                              32;
                      return FlexibleSpaceBar(
                        titlePadding: const EdgeInsetsDirectional.only(
                          start: 72,
                          end: 24,
                          bottom: 16,
                        ),
                        title: collapsed
                            ? Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.small,
                                    ),
                                    child: PlaceCoverImage(
                                      url: place.coverImageUrl,
                                      vibe: place.vibe,
                                      width: 36,
                                      height: 36,
                                      fade: false,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.compact),
                                  Expanded(
                                    child: Text(
                                      place.localizedName(l10n),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.titleMedium
                                          ?.copyWith(
                                            color: palette.textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              itemCount: gallery.length,
                              onPageChanged: (index) =>
                                  setState(() => _photoIndex = index),
                              itemBuilder: (context, index) => AppHero(
                                tag: index == coverIndex
                                    ? widget.coverHeroTag
                                    : null,
                                url: gallery[index].imageUrl,
                                radius: 0,
                                child: PlaceCoverImage(
                                  url: gallery[index].imageUrl,
                                  vibe: place.vibe,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fade: false,
                                ),
                              ),
                            ),
                            if (gallery.length > 1)
                              PositionedDirectional(
                                end: AppSpacing.md,
                                bottom: AppSpacing.xxl,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      '${l10n.n((_photoIndex + 1).clamp(1, gallery.length))} / ${l10n.n(gallery.length)}',
                                      style: context.texts.labelMedium,
                                    ),
                                  ),
                                ),
                              ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: AppRadii.sheet,
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppRadii.sheet),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      24,
                      0,
                      24,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_failed)
                          TextButton(
                            onPressed: _load,
                            child: Text(l10n.catalogRetry),
                          ),
                        Text(
                          place.localizedName(l10n),
                          style: context.texts.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        if (place.localizedSummary(l10n).isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            place.localizedSummary(l10n),
                            style: context.texts.bodyMedium?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            AppBadge(
                              label: l10n.vibeLabel(place.vibe.name),
                              color: palette.brandSoft,
                              textColor: palette.brandStrong,
                            ),
                            if (place.hasKnownPrice)
                              AppBadge(
                                label: l10n.priceLevelLabel(
                                  place.priceLevel.name,
                                ),
                                color: palette.brandSoft,
                                textColor: palette.brandStrong,
                              ),
                            if (place.status != 'active')
                              AppBadge(
                                label: l10n.catalogStatus(place.status),
                                color: palette.surfaceMuted,
                                textColor: palette.textSecondary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PlaceTabsHeader(
                    tabs: tabs,
                    color: surface,
                    height:
                        56 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
                          0,
                          double.infinity,
                        ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _PlaceOverview(place: place),
                  place.brandId.isNotEmpty && place.branchCount > 1
                      ? PlaceBranchList(
                          current: place.toOutingPlace(),
                          onSelected: (branch) => Get.to(
                            () => DiscoverPlaceDetailsPage(
                              placeId: branch.id,
                              initialPlace: branch,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.storefront_outlined),
                              title: Text(
                                place.branchName.isEmpty
                                    ? place.localizedName(l10n)
                                    : place.branchName,
                              ),
                              subtitle: place.branchLabel.isEmpty
                                  ? null
                                  : Text(place.branchLabel),
                              selected: true,
                            ),
                          ],
                        ),
                  ReviewsListPage(
                    placeId: place.id,
                    initialStatistics: place.ratingStatistics,
                    acceptsRatings: place.status == 'active',
                    embedded: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final save = SavePlaceButton(
                          key: ValueKey(place.id),
                          place: place,
                          showLabel: true,
                        );
                        final directions = CustomButton(
                          label: l10n.placeDirections,
                          icon: Icons.directions_outlined,
                          onPressed:
                              (place.latitude != null &&
                                      place.longitude != null) ||
                                  place.address.isNotEmpty
                              ? () async {
                                  final opened =
                                      await AppLauncher.openDirections(
                                        latitude: place.latitude,
                                        longitude: place.longitude,
                                        query: place.address.isEmpty
                                            ? place.localizedName(l10n)
                                            : place.address,
                                      );
                                  if (!opened && context.mounted) {
                                    AppSnackBar.showError(
                                      l10n.couldNotOpenLink,
                                    );
                                  }
                                }
                              : null,
                        );
                        if (constraints.maxWidth < 320 ||
                            MediaQuery.textScalerOf(context).scale(14) > 20) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              save,
                              const SizedBox(height: AppSpacing.sm),
                              directions,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: save),
                            const SizedBox(width: AppSpacing.compact),
                            Expanded(child: directions),
                          ],
                        );
                      },
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: place.status == 'active'
                          ? () => Get.to(
                              () => CreateOutingPage(suggestedPlace: place),
                            )
                          : null,
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(l10n.planOutingHere),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceTabsHeader extends SliverPersistentHeaderDelegate {
  _PlaceTabsHeader({
    required this.tabs,
    required this.color,
    required this.height,
  });
  final TabBar tabs;
  final Color color;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(color: color, child: tabs);
  @override
  bool shouldRebuild(covariant _PlaceTabsHeader oldDelegate) =>
      oldDelegate.tabs != tabs ||
      oldDelegate.color != color ||
      oldDelegate.height != height;
}

class _PlaceOverview extends StatelessWidget {
  const _PlaceOverview({required this.place});
  final SuggestedPlace place;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        RatingsSummaryWidget(
          placeId: place.id,
          statistics: place.ratingStatistics,
        ),
        const SizedBox(height: AppSpacing.md),
        if (place.localizedDescription(l10n).trim().isNotEmpty) ...[
          Text(
            place.localizedDescription(l10n),
            style: context.texts.bodyLarge?.copyWith(
              height: 1.6,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (place.address.isNotEmpty || place.area.isNotEmpty)
          _PlaceInfoRow(
            icon: Icons.location_on_outlined,
            text: place.address.isEmpty
                ? place.localizedArea(l10n)
                : place.address,
          ),
        if (place.openingHours.isNotEmpty)
          _PlaceInfoRow(
            icon: Icons.schedule_outlined,
            text: place.openingHours,
          ),
        if (place.distanceKm != null)
          _PlaceInfoRow(
            icon: Icons.near_me_outlined,
            text: l10n.catalogDistanceLabel(place.distanceKm!),
          ),
        if (place.prices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.prices,
            style: context.texts.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final price in place.prices)
            _PlaceValueRow(
              label: l10n.discoverPriceLabel(price.labelKey),
              value: l10n.formatPrice(price.amount, price.currency),
            ),
        ],
        if (place.hours.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.workingHours,
            style: context.texts.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final hour in place.hours)
            _PlaceValueRow(
              label: l10n.weekdayLabel(hour.day.name),
              value: hour.isClosed
                  ? l10n.closed
                  : '${l10n.formatClock(hour.opensAt ?? '')} – ${l10n.formatClock(hour.closesAt ?? '')}',
            ),
        ],
        if (place.source == 'osm' || place.source == 'overture') ...[
          const SizedBox(height: AppSpacing.xl),
          const PlaceCatalogAttribution(),
        ],
      ],
    );
  }
}

class _PlaceInfoRow extends StatelessWidget {
  const _PlaceInfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.palette.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: context.texts.bodyMedium)),
      ],
    ),
  );
}

class _PlaceValueRow extends StatelessWidget {
  const _PlaceValueRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        Text(label, style: context.texts.bodyMedium),
        Text(
          value,
          style: context.texts.bodyMedium?.copyWith(
            color: context.palette.brandStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
