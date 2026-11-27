import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/place_reviews/presentation/widgets/ratings_summary_widget.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_place_details_page.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_category_style.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/save_place_button.dart';

class ExplorePlaceCard extends StatelessWidget {
  const ExplorePlaceCard({super.key, required this.place, this.category});

  final SuggestedPlace place;
  final CatalogDefinition? category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final radius = BorderRadius.circular(18);
    final name = place.localizedName(l10n);
    final categoryLabel = category?.label(l10n.locale.languageCode) ?? '';
    final icon = switch (place.categoryId) {
      'cafes' || 'coffee_shops' => Icons.local_cafe_outlined,
      'restaurants' || 'fast_food' => Icons.restaurant_outlined,
      'parks' || 'gardens' => Icons.park_outlined,
      _ => place.vibe.icon,
    };
    final heroTag = HeroTags.placeCover('home-nearby', place.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        AppPressable(
          onTap: () => Get.to(
            () => DiscoverPlaceDetailsPage(
              placeId: place.id,
              initialPlace: place,
              coverHeroTag: heroTag,
              coverUrl: place.coverImageUrl,
            ),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFBFB0DB).withValues(alpha: .34),
              ),
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppHero(
                    tag: heroTag,
                    url: place.coverImageUrl,
                    radius: 18,
                    child: PlaceCoverImage.fromSuggested(
                      place: place,
                      fade: false,
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x00161322),
                          Color(0xED221C30),
                          Color(0xFF241E30),
                        ],
                        stops: [0, .36, .84, 1],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 11,
                    end: 11,
                    bottom: 11,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.titleSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.22,
                          ),
                        ),
                        RatingsSummaryWidget(
                          placeId: place.id,
                          statistics: place.ratingStatistics,
                          compact: true,
                          onPhoto: true,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              icon,
                              color: const Color(0xFFF0E9FA),
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                categoryLabel.isEmpty
                                    ? l10n.vibeLabel(place.vibe.name)
                                    : categoryLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall?.copyWith(
                                  color: const Color(0xFFF0E9FA),
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: SavePlaceButton(place: place, photoOverlay: true),
        ),
      ],
    );
  }
}
