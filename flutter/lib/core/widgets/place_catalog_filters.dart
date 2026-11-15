import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';

/// Backend labels/IDs remain extensible; unknown icons use the established place icon.
class PlaceCatalogFilters extends StatelessWidget {
  const PlaceCatalogFilters({
    super.key,
    required this.catalog,
    this.compact = false,
  });
  final PlaceCatalogProvider catalog;
  final bool compact;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: catalog,
    builder: (context, _) {
      final filters = catalog.filters;
      Widget chip(CatalogDefinition item, bool vibe) {
        final selected = (vibe ? filters.vibes : filters.categories).contains(
          item.id,
        );
        return FilterChip(
          label: Text(item.label(context.l10n.locale.languageCode)),
          avatar: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Icon(
              catalogIcon(item.icon, selected),
              key: ValueKey(selected),
              size: 20,
            ),
          ),
          selected: selected,
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (value) {
            final ids = {...(vibe ? filters.vibes : filters.categories)};
            if (value) {
              ids.add(item.id);
            } else {
              ids.remove(item.id);
            }
            catalog.update(
              vibe
                  ? filters.copyWith(vibes: ids)
                  : filters.copyWith(categories: ids),
            );
          },
        );
      }

      if (compact) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final items in [catalog.categories, catalog.vibes])
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (identical(items, catalog.categories)) ...[
                      IconButton.filledTonal(
                        tooltip: context.l10n.mapFilters,
                        onPressed: () => AppBottomSheet.show<void>(
                          context: context,
                          builder: (_) => PlaceCatalogFilters(catalog: catalog),
                        ),
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton.filledTonal(
                        tooltip: context.l10n.catalogClearFilters,
                        onPressed: () => catalog.update(const PlaceFilters()),
                        icon: const Icon(Icons.filter_alt_off_outlined),
                      ),
                    ],
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: chip(item, identical(items, catalog.vibes)),
                      ),
                  ],
                ),
              ),
            if (catalog.taxonomyFailed)
              TextButton(
                onPressed: () => catalog.loadDefinitions(force: true),
                child: Text(context.l10n.catalogRetryCategories),
              ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => catalog.update(const PlaceFilters()),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: Text(context.l10n.catalogClearFilters),
            ),
          ),
          if (catalog.taxonomyFailed)
            TextButton.icon(
              onPressed: () => catalog.loadDefinitions(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.catalogRetryCategories),
            ),
          if (catalog.categories.isEmpty &&
              !catalog.taxonomyFailed &&
              catalog.definitionsLoaded)
            Text(context.l10n.catalogNoCategories),
          for (final group in catalog.categories.map((c) => c.group).toSet())
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                context.l10n.catalogGroup(group),
                style: context.texts.titleSmall,
              ),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: Responsive.spaceSm,
                    runSpacing: Responsive.spaceXs,
                    children: [
                      for (final c in catalog.categories.where(
                        (c) => c.group == group,
                      ))
                        chip(c, false),
                    ],
                  ),
                ),
              ],
            ),
          Text(context.l10n.placeVibes, style: context.texts.titleSmall),
          Wrap(
            spacing: Responsive.spaceSm,
            runSpacing: Responsive.spaceXs,
            children: [for (final v in catalog.vibes) chip(v, true)],
          ),
          if (filters.latitude != null)
            DropdownButtonFormField<double>(
              initialValue: filters.radiusKm,
              decoration: InputDecoration(
                labelText: context.l10n.catalogDistance,
              ),
              items: [
                for (final km in [1.0, 5.0, 10.0, 25.0, 50.0])
                  DropdownMenuItem(
                    value: km,
                    child: Text(context.l10n.catalogKm(km)),
                  ),
              ],
              onChanged: (km) {
                if (km != null) catalog.update(filters.copyWith(radiusKm: km));
              },
            ),
        ],
      );
    },
  );
}

IconData catalogIcon(String icon, bool selected) => switch (icon) {
  'restaurant' => selected ? Icons.restaurant : Icons.restaurant_outlined,
  'fastfood' => selected ? Icons.fastfood : Icons.fastfood_outlined,
  'bakery_dining' =>
    selected ? Icons.bakery_dining : Icons.bakery_dining_outlined,
  'cake' => selected ? Icons.cake : Icons.cake_outlined,
  'icecream' => selected ? Icons.icecream : Icons.icecream_outlined,
  'lock' => selected ? Icons.lock : Icons.lock_outline,
  'view_in_ar' => selected ? Icons.view_in_ar : Icons.view_in_ar_outlined,
  'sports_gymnastics' =>
    selected ? Icons.sports_gymnastics : Icons.sports_gymnastics_outlined,
  'sports' => selected ? Icons.sports : Icons.sports_outlined,
  'attractions' => selected ? Icons.attractions : Icons.attractions_outlined,
  'local_florist' =>
    selected ? Icons.local_florist : Icons.local_florist_outlined,
  'pets' => selected ? Icons.pets : Icons.pets_outlined,
  'landscape' => selected ? Icons.landscape : Icons.landscape_outlined,
  'sports_motorsports' =>
    selected ? Icons.sports_motorsports : Icons.sports_motorsports_outlined,
  'fitness_center' =>
    selected ? Icons.fitness_center : Icons.fitness_center_outlined,
  'hiking' => selected ? Icons.hiking : Icons.hiking_outlined,
  'palette' => selected ? Icons.palette : Icons.palette_outlined,
  'theater_comedy' =>
    selected ? Icons.theater_comedy : Icons.theater_comedy_outlined,
  'weekend' => selected ? Icons.weekend : Icons.weekend_outlined,
  'local_cafe' ||
  'coffee' => selected ? Icons.local_cafe : Icons.local_cafe_outlined,
  'movie' => selected ? Icons.movie : Icons.movie_outlined,
  'park' || 'forest' => selected ? Icons.park : Icons.park_outlined,
  'shopping_bag' ||
  'store' ||
  'storefront' => selected ? Icons.shopping_bag : Icons.shopping_bag_outlined,
  'museum' ||
  'account_balance' => selected ? Icons.museum : Icons.museum_outlined,
  'groups' ||
  'family_restroom' => selected ? Icons.groups : Icons.groups_outlined,
  'sports_esports' =>
    selected ? Icons.sports_esports : Icons.sports_esports_outlined,
  'favorite' => selected ? Icons.favorite : Icons.favorite_outline,
  'spa' => selected ? Icons.spa : Icons.spa_outlined,
  'savings' => selected ? Icons.savings : Icons.savings_outlined,
  'school' => selected ? Icons.school : Icons.school_outlined,
  _ => selected ? Icons.place : Icons.place_outlined,
};

class CatalogLoadMore extends StatelessWidget {
  const CatalogLoadMore({super.key, required this.catalog});
  final PlaceCatalogProvider catalog;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: catalog,
    builder: (context, _) => Column(
      children: [
        if (catalog.error != null)
          TextButton(
            onPressed: () => catalog.load(force: true),
            child: Text(context.l10n.catalogRetry),
          ),
        if (catalog.hasMore && !catalog.loading)
          TextButton(
            onPressed: () => catalog.load(more: true),
            child: Text(context.l10n.catalogMore),
          ),
        const PlaceCatalogAttribution(),
      ],
    ),
  );
}

class PlaceCatalogAttribution extends StatelessWidget {
  const PlaceCatalogAttribution({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          '© OpenStreetMap contributors · ODbL 1.0',
          style: context.texts.bodySmall,
        ),
      ),
      TextButton(
        onPressed: () => launchUrl(
          Uri.parse('https://docs.overturemaps.org/attribution/'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          'Overture Maps Foundation · CDLA Permissive 2.0',
          style: context.texts.bodySmall,
        ),
      ),
    ],
  );
}
