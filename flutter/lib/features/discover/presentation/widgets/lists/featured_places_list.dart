import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  });

  final List<SuggestedPlace> places;
  final bool compact;
  final bool showPriceLevel;
  final String? title;

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
            height: 168.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == places.length - 1 ? 0 : Responsive.spaceSm,
                  ),
                  child: DiscoverPlaceCard(
                    place: place,
                    compact: compact,
                    showPriceLevel: showPriceLevel,
                    onTap: () => Get.to(
                      () => DiscoverPlaceDetailsPage(placeId: place.id),
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
