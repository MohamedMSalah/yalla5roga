import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/place_catalog_provider.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/widgets/meetup_entry_selector.dart';

class DiscoverFilterChips extends StatelessWidget {
  const DiscoverFilterChips({super.key, required this.catalog});
  final PlaceCatalogProvider catalog;

  @override
  Widget build(BuildContext context) {
    final filters = catalog.filters;
    final all =
        !catalog.privateOnly &&
        filters.categories.isEmpty &&
        filters.vibes.isEmpty &&
        !filters.hasRatingCriteria;
    void clearFilters() {
      if (!all) {
        catalog.privateOnly = false;
        catalog.update(
          filters.copyWith(
            categories: {},
            vibes: {},
            topRated: false,
            clearMinRating: true,
          ),
          debounce: true,
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 6),
      child: Row(
        spacing: 8,
        children: [
          if (catalog.privateOwner != null)
            _CategoryChip(
              label: context.l10n.smartMeetup,
              icon: Icons.route_outlined,
              onTap: () => MeetupEntrySelector.show(context),
            ),
          _CategoryChip(
            label: context.l10n.discoverAllPlaces,
            icon: Icons.grid_view_rounded,
            selected: all,
            onTap: clearFilters,
          ),
          if (catalog.privateOwner != null)
            _CategoryChip(
              label: context.l10n.myPrivatePlaces,
              icon: Icons.lock_outline,
              selected: catalog.privateOnly,
              onTap: () {
                catalog.privateOnly = !catalog.privateOnly;
                catalog.update(
                  filters.copyWith(topRated: false, clearMinRating: true),
                );
              },
            ),
          if (!all)
            _CategoryChip(
              label: context.l10n.catalogClearFilters,
              icon: Icons.filter_alt_off_outlined,
              onTap: clearFilters,
            ),
          _CategoryChip(
            label: context.l10n.discoverTopRated,
            icon: Icons.star_outline_rounded,
            selected: filters.topRated,
            onTap: () {
              catalog.privateOnly = false;
              catalog.update(filters.copyWith(topRated: !filters.topRated));
            },
          ),
          MinimumRatingFilterChips(
            minimum: filters.minRating,
            onChanged: (minimum) {
              catalog.privateOnly = false;
              catalog.update(
                filters.copyWith(
                  minRating: minimum,
                  clearMinRating: minimum == null,
                ),
              );
            },
          ),
          for (final (items, vibe) in [
            (catalog.categories, false),
            (catalog.vibes, true),
          ])
            for (final item in items) _chip(context, item, vibe),
          if (catalog.taxonomyFailed)
            _CategoryChip(
              label: context.l10n.catalogRetryCategories,
              icon: Icons.refresh,
              onTap: () => catalog.loadDefinitions(force: true),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, CatalogDefinition item, bool vibe) {
    final filters = catalog.filters;
    final ids = vibe ? filters.vibes : filters.categories;
    final selected = ids.contains(item.id);
    return _CategoryChip(
      label: item.label(context.l10n.locale.languageCode),
      icon: catalogIcon(item.icon, false),
      selected: selected,
      onTap: () {
        final next = {...ids};
        selected ? next.remove(item.id) : next.add(item.id);
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

class MinimumRatingFilterChips extends StatelessWidget {
  const MinimumRatingFilterChips({
    super.key,
    required this.minimum,
    required this.onChanged,
  });

  final double? minimum;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final threshold in const <double>[3, 4, 4.5])
          _CategoryChip(
            label: l10n.minimumPlaceRating(
              l10n.digits(
                threshold.toStringAsFixed(threshold % 1 == 0 ? 0 : 1),
              ),
            ),
            icon: Icons.star_rounded,
            selected: minimum == threshold,
            onTap: () => onChanged(minimum == threshold ? null : threshold),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final highContrast = MediaQuery.highContrastOf(context);
    final color = selected ? AppPalette.gradientText : palette.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.standard),
        decoration: ShapeDecoration(
          color: selected
              ? (highContrast ? palette.chipActive : null)
              : palette.surface,
          gradient: selected && !highContrast
              ? AppPalette.selectedGradient
              : null,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppPalette.selectionHighlight : palette.border,
            ),
          ),
          shadows: selected && palette.isDark && !highContrast
              ? [
                  BoxShadow(
                    color: AppPalette.selectionHighlight.withValues(alpha: .20),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 9,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: highContrast && selected
                              ? palette.chipActiveText
                              : color,
                        ),
                        Text(
                          label,
                          style: context.texts.labelLarge?.copyWith(
                            color: highContrast && selected
                                ? palette.chipActiveText
                                : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (selected && !highContrast)
                  const SizedBox(
                    width: 30,
                    height: 2,
                    child: ColoredBox(color: AppPalette.selectionHighlight),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
