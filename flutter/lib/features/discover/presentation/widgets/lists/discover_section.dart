import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_fade_switcher.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/featured_places_list.dart';
import 'package:yalla_5roga/features/discover/presentation/pages/discover_page.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';

/// Discover section list used on Home / Outings tabs.
class DiscoverSection extends StatelessWidget {
  const DiscoverSection({
    super.key,
    this.compact = true,
    this.limit = 5,
    this.heroSurface = 'section',
  });

  final bool compact;
  final int limit;

  /// Home and Outings tabs both embed this section on one route; each passes
  /// its own surface so place Hero tags never collide.
  final String heroSurface;

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
        // Shimmer -> list reveals once per load state; the key does not
        // change when the list contents refresh.
        AppFadeSwitcher(
          child: !discover.hasLoaded
              ? AppShimmer(
                  key: const ValueKey('loading'),
                  child: ShimmerBone(
                    width: double.infinity,
                    height: 120.h,
                    radius: 24.r,
                  ),
                )
              : featured.isEmpty
              ? AppEmptyState(
                  key: const ValueKey('empty'),
                  icon: Icons.travel_explore_outlined,
                  message: l10n.noPlaces,
                  subtitle: l10n.noPlacesHint,
                  compact: true,
                )
              : FeaturedPlacesList(
                  key: const ValueKey('list'),
                  places: featured,
                  compact: compact,
                  showPriceLevel: false,
                  heroSurface: '$heroSurface-featured',
                ),
        ),
      ],
    );
  }
}
