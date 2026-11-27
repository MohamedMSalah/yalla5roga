import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/place_reviews/presentation/widgets/ratings_summary_widget.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/place_cover_image.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/save_place_button.dart';

class DiscoverPlaceCard extends StatelessWidget {
  const DiscoverPlaceCard({
    super.key,
    required this.place,
    required this.category,
    required this.vibes,
    required this.selected,
    required this.onSelect,
    required this.onDetails,
    required this.onCreate,
    this.distanceKm,
    this.onBranches,
  });

  final SuggestedPlace place;
  final CatalogDefinition? category;
  final String vibes;
  final double? distanceKm;
  final bool selected;
  final VoidCallback? onBranches;
  final VoidCallback onSelect, onDetails, onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    return Semantics(
      selected: selected,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected ? palette.brandSoftBorder : palette.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(9, 9, 10, 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageWidth = (constraints.maxWidth * .30).clamp(
                        0.0,
                        constraints.maxHeight * 1.22,
                      );
                      return Row(
                        spacing: 12,
                        children: [
                          SizedBox(
                            width: imageWidth,
                            height: constraints.maxHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PlaceCoverImage.fromSuggested(
                                  place: place,
                                  radius: 16,
                                  width: imageWidth,
                                  height: constraints.maxHeight,
                                ),
                                if (!place.id.startsWith('private:') &&
                                    imageWidth >= 48 &&
                                    constraints.maxHeight >= 48)
                                  PositionedDirectional(
                                    top: 0,
                                    end: 0,
                                    child: SavePlaceButton(
                                      place: place,
                                      photoOverlay: true,
                                      heart: true,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              primary: false,
                              child: _PlaceDescription(
                                place: place,
                                category: category,
                                vibes: vibes,
                                distanceKm: distanceKm,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 8, 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: palette.border.withValues(alpha: .65),
                      ),
                    ),
                  ),
                  child: Row(
                    spacing: 4,
                    children: [
                      if (selected)
                        Flexible(
                          child: TextButton(
                            onPressed: onCreate,
                            style: TextButton.styleFrom(
                              foregroundColor: palette.brandStrong,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            child: Text(
                              l10n.discoverCreateOutingHere,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (place.branchCount > 1 && onBranches != null)
                        IconButton(
                          tooltip: l10n.chooseBranch,
                          onPressed: onBranches,
                          color: palette.textSecondary,
                          icon: const Icon(Icons.account_tree_outlined),
                        ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _ViewDetailsButton(onPressed: onDetails),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceDescription extends StatelessWidget {
  const _PlaceDescription({
    required this.place,
    required this.category,
    required this.vibes,
    required this.distanceKm,
  });

  final SuggestedPlace place;
  final CatalogDefinition? category;
  final String vibes;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final definition = category;
    final label = definition?.label(l10n.locale.languageCode) ?? '';
    final locality = place.branchLabel.isNotEmpty
        ? place.branchLabel
        : place.localizedArea(l10n);
    final metadata = locality == label ? '' : locality;
    final distance = distanceKm == null
        ? ''
        : l10n.catalogDistanceLabel(distanceKm!);
    final group = definition == null ? '' : l10n.catalogGroup(definition.group);
    final secondary = group.isNotEmpty && group != label ? group : vibes;
    final small = context.texts.bodySmall?.copyWith(
      color: palette.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (definition != null && label.isNotEmpty)
          DecoratedBox(
            decoration: ShapeDecoration(
              color: palette.brandSoft,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 5,
                children: [
                  Icon(
                    catalogIcon(definition.icon, false),
                    size: 14,
                    color: palette.brandStrong,
                  ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.brandStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          place.localizedName(l10n),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.texts.titleLarge?.copyWith(
            fontSize: 18,
            height: 1.13,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        RatingsSummaryWidget(
          placeId: place.id,
          statistics: place.ratingStatistics,
          compact: true,
        ),
        if (metadata.isNotEmpty || distance.isNotEmpty)
          Row(
            spacing: 4,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: palette.textSecondary,
              ),
              if (metadata.isNotEmpty)
                Flexible(
                  child: Text(
                    metadata,
                    style: small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (distance.isNotEmpty)
                Flexible(
                  child: Text(
                    metadata.isEmpty ? distance : '· $distance',
                    style: small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        if (secondary.isNotEmpty && secondary != label && secondary != metadata)
          Text(
            secondary,
            style: small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _ViewDetailsButton extends StatelessWidget {
  const _ViewDetailsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final highContrast = MediaQuery.highContrastOf(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: highContrast ? palette.chipActive : null,
        gradient: highContrast ? null : AppPalette.actionGradient,
        shape: const StadiumBorder(
          side: BorderSide(color: AppPalette.selectionHighlight),
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: highContrast
              ? palette.chipActiveText
              : AppPalette.gradientText,
          minimumSize: const Size(48, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsetsDirectional.fromSTEB(15, 8, 10, 8),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Flexible(
              child: Text(
                context.l10n.discoverViewDetails,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.ltr
                  ? Icons.chevron_right
                  : Icons.chevron_left,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
