import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/filter_chip_row.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/featured_places_list.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/lists/nearby_places_list.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discover = context.watch<DiscoverProvider>();

    return Scaffold(
      appBar: AppPageBar(title: l10n.discover),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: Responsive.pagePadding(),
          children: [
            SectionHeader(
              eyebrow: l10n.discover,
              title: l10n.nearbyPlaces,
              subtitle: l10n.discoverSubtitle,
            ),
            Responsive.spaceMd.gapH,
            FilterChipRow(
              labels: [
                l10n.allVibes,
                l10n.food,
                l10n.activity,
                l10n.outdoor,
                l10n.movie,
              ],
              index: discover.filter,
              onChanged: discover.setFilter,
            ),
            Responsive.spaceLg.gapH,
            FeaturedPlacesList(
              places: discover.featured,
              title: l10n.featuredPlaces,
            ),
            Responsive.spaceLg.gapH,
            NearbyPlacesList(places: discover.places, title: l10n.allPlaces),
          ],
        ),
      ),
    );
  }
}
