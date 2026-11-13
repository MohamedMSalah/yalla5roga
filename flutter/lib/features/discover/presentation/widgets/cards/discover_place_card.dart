import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/place_card.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';

/// Horizontal featured place card used in Discover carousels.
class DiscoverPlaceCard extends StatelessWidget {
  const DiscoverPlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.compact = false,
    this.showPriceLevel = true,
    this.heroTag,
  });

  final SuggestedPlace place;
  final VoidCallback onTap;
  final bool compact;
  final bool showPriceLevel;

  /// Shared-element tag for the cover; pass the same tag to place details.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PlaceCard(
      title: place.localizedName(l10n),
      subtitle: showPriceLevel
          ? '${place.localizedArea(l10n)} · ${l10n.priceLevelLabel(place.priceLevel.name)}'
          : place.localizedArea(l10n),
      compact: compact,
      onTap: onTap,
      cover: AppHero(
        tag: heroTag,
        url: place.coverImageUrl,
        radius: 16.r,
        child: PlaceCoverImage.fromSuggested(
          place: place,
          width: compact ? 200.w : 220.w,
          height: 168.h,
          fit: BoxFit.cover,
          fade: false,
        ),
      ),
    );
  }
}
