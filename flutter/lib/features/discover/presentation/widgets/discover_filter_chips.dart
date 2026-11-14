import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';

class DiscoverFilterChips extends StatelessWidget {
  const DiscoverFilterChips({super.key, required this.catalog});
  final PlaceCatalogProvider catalog;

  @override
  Widget build(BuildContext context) {
    final filters = catalog.filters;
    final all = filters.categories.isEmpty && filters.vibes.isEmpty;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: FilterChip(
              label: Text(context.l10n.discoverAllPlaces),
              selected: all,
              onSelected: (_) {
                if (!all)
                  catalog.update(
                    filters.copyWith(categories: {}, vibes: {}),
                    debounce: true,
                  );
              },
            ),
          ),
          if (!all)
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 20),
              label: Text(context.l10n.catalogClearFilters),
              onPressed: () => catalog.update(
                filters.copyWith(categories: {}, vibes: {}),
                debounce: true,
              ),
            ),
          for (final (items, vibe) in [
            (catalog.categories, false),
            (catalog.vibes, true),
          ])
            for (final item in items)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: _chip(context, item, vibe),
              ),
          if (catalog.taxonomyFailed)
            ActionChip(
              label: Text(context.l10n.catalogRetryCategories),
              onPressed: () => catalog.loadDefinitions(force: true),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, CatalogDefinition item, bool vibe) {
    final filters = catalog.filters;
    final ids = vibe ? filters.vibes : filters.categories;
    final selected = ids.contains(item.id);
    return FilterChip(
      label: Text(item.label(context.l10n.locale.languageCode)),
      avatar: Icon(catalogIcon(item.icon, selected), size: 20),
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (value) {
        final next = {...ids};
        value ? next.add(item.id) : next.remove(item.id);
        catalog.update(
          vibe
              ? filters.copyWith(vibes: next)
              : filters.copyWith(categories: next),
          debounce: true,
        );
      },
    );
  }
}
