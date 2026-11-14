import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart'
    show PlaceCatalogAttribution;
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
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

    return Scaffold(
      appBar: AppPageBar(title: place.localizedName(l10n)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: Responsive.pagePadding(),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_failed)
                  TextButton(onPressed: _load, child: Text(l10n.catalogRetry)),
                SizedBox(
                  height: 210.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == gallery.length - 1
                              ? 0
                              : Responsive.spaceSm,
                        ),
                        child: AppHero(
                          tag: index == coverIndex ? widget.coverHeroTag : null,
                          url: gallery[index].imageUrl,
                          radius: 18.r,
                          child: PlaceCoverImage(
                            url: gallery[index].imageUrl,
                            vibe: place.vibe,
                            width: 280.w,
                            height: 210.h,
                            fade: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Responsive.spaceMd.gapH,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.localizedName(l10n),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontLg,
                        ),
                      ),
                    ),
                    AppBadge(
                      label: l10n.vibeLabel(place.vibe.name),
                      color: palette.brandSoft,
                      textColor: palette.brandStrong,
                    ),
                  ],
                ),
                Responsive.spaceXs.gapH,
                Text(
                  place.localizedSummary(l10n),
                  style: TextStyle(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.fontSm,
                  ),
                ),
                if (place.status != 'active')
                  AppBadge(
                    label: l10n.catalogStatus(place.status),
                    color: palette.brandSoft,
                    textColor: palette.brandStrong,
                  ),
                if (place.openingHours.isNotEmpty) Text(place.openingHours),
                if (place.address.isNotEmpty) Text(place.address),
                if (place.source == 'osm') const PlaceCatalogAttribution(),
                if (place.localizedDescription(l10n).trim().isNotEmpty) ...[
                  Responsive.spaceMd.gapH,
                  Text(
                    l10n.aboutPlace,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontMd,
                    ),
                  ),
                  Responsive.spaceXs.gapH,
                  Text(
                    place.localizedDescription(l10n),
                    style: TextStyle(
                      color: palette.textSecondary,
                      height: 1.45,
                      fontSize: Responsive.fontSm,
                    ),
                  ),
                ],
                if (place.prices.isNotEmpty) ...[
                  Responsive.spaceLg.gapH,
                  Text(
                    l10n.prices,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontMd,
                    ),
                  ),
                  Responsive.spaceSm.gapH,
                  for (final price in place.prices) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.discoverPriceLabel(price.labelKey),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSm,
                            ),
                          ),
                        ),
                        Text(
                          l10n.formatPrice(price.amount, price.currency),
                          style: TextStyle(
                            color: AppColors.brand600,
                            fontWeight: FontWeight.w800,
                            fontSize: Responsive.fontSm,
                          ),
                        ),
                      ],
                    ),
                    Responsive.spaceXs.gapH,
                  ],
                ],
                if (place.hours.isNotEmpty) ...[
                  Responsive.spaceLg.gapH,
                  Text(
                    l10n.workingHours,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontMd,
                    ),
                  ),
                  Responsive.spaceSm.gapH,
                  for (final hour in place.hours) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.weekdayLabel(hour.day.name),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSm,
                            ),
                          ),
                        ),
                        Text(
                          hour.isClosed
                              ? l10n.closed
                              : '${l10n.formatClock(hour.opensAt ?? '')} – ${l10n.formatClock(hour.closesAt ?? '')}',
                          style: TextStyle(
                            color: hour.isClosed
                                ? palette.textMuted
                                : palette.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: Responsive.fontSm,
                          ),
                        ),
                      ],
                    ),
                    Responsive.spaceXs.gapH,
                  ],
                ],
                Responsive.spaceXl.gapH,
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: Responsive.padding(horizontal: 16, top: 8, bottom: 8),
              child: CustomButton(
                label: l10n.planOutingHere,
                icon: Icons.event_available_outlined,
                onPressed: place.status == 'active'
                    ? () =>
                          Get.to(() => CreateOutingPage(suggestedPlace: place))
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
