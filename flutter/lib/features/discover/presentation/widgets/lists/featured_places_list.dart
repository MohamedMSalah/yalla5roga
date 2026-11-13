import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/cards/discover_place_card.dart';

/// Featured places list: optional title + horizontal place cards / empty state.
class FeaturedPlacesList extends StatelessWidget {
  const FeaturedPlacesList({
    super.key,
    required this.places,
    this.compact = false,
    this.showPriceLevel = true,
    this.title,
    this.heroSurface = 'discover-featured',
  });

  final List<SuggestedPlace> places;
  final bool compact;
  final bool showPriceLevel;
  final String? title;

  /// Keeps Hero tags unique across lists that share a route.
  final String heroSurface;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!.toUpperCase(),
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: Responsive.fontCaption,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          Responsive.spaceSm.gapH,
        ],
        if (places.isEmpty)
          AppEmptyState(
            icon: Icons.travel_explore_outlined,
            message: l10n.noPlaces,
            subtitle: l10n.noPlacesHint,
            compact: true,
          )
        else
          SizedBox(
            height:
                168.h +
                (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                      0.0,
                      2.0,
                    ) *
                    40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              addAutomaticKeepAlives: false,
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                final heroTag = HeroTags.placeCover(heroSurface, place.id);
                return Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: index == places.length - 1 ? 0 : Responsive.spaceSm,
                  ),
                  child: DiscoverPlaceCard(
                    place: place,
                    compact: compact,
                    showPriceLevel: showPriceLevel,
                    heroTag: heroTag,
                    onTap: () => Get.to(
                      () => DiscoverPlaceDetailsPage(
                        placeId: place.id,
                        coverHeroTag: heroTag,
                        coverUrl: place.coverImageUrl,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
