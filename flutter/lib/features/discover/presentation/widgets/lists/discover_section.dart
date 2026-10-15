import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/featured_places_list.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/nearby_places_list.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';

/// Discover section list used on Home / Outings tabs.
class DiscoverSection extends StatelessWidget {
  const DiscoverSection({
    super.key,
    this.compact = true,
    this.limit = 5,
    this.showPlaces = false,
  });

  final bool compact;
  final int limit;
  final bool showPlaces;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discover = context.watch<DiscoverProvider>();
    final featured = discover.featuredPlaces.take(limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.discover,
          subtitle: l10n.exploreNearby,
          actionLabel: l10n.seeAll,
          onAction: () => Get.to(() => const DiscoverPage()),
        ),
        12.gapH,
        if (!discover.hasLoaded)
          AppShimmer(
            child: ShimmerBone(
              width: double.infinity,
              height: 120.h,
              radius: 24.r,
            ),
          )
        else if (featured.isEmpty)
          AppEmptyState(
            icon: Icons.travel_explore_outlined,
            message: l10n.noPlaces,
            subtitle: l10n.noPlacesHint,
            compact: true,
          )
        else
          FeaturedPlacesList(
            places: featured,
            compact: compact,
            showPriceLevel: false,
          ),
        if (showPlaces && discover.hasLoaded) ...[
          Responsive.spaceMd.gapH,
          NearbyPlacesList(
            places: discover.places.take(3).toList(),
            title: l10n.nearbyPlaces,
          ),
        ],
      ],
    );
  }
}
