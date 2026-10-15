import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';

/// Horizontal featured place card used in Discover carousels.
class DiscoverPlaceCard extends StatelessWidget {
  const DiscoverPlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.compact = false,
    this.showPriceLevel = true,
  });

  final SuggestedPlace place;
  final VoidCallback onTap;
  final bool compact;
  final bool showPriceLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = compact ? 200.w : 220.w;
    final height = compact ? 168.h : 168.h;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: context.palette.shadow,
              blurRadius: 18.w,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlaceCoverImage.fromSuggested(place: place, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12.w,
                right: 12.w,
                bottom: 12.h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.localizedName(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: Responsive.fontSm,
                      ),
                    ),
                    2.gapH,
                    Text(
                      showPriceLevel
                          ? '${place.localizedArea(l10n)} · ${l10n.priceLevelLabel(place.priceLevel.name)}'
                          : place.localizedArea(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: Responsive.fontCaption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
