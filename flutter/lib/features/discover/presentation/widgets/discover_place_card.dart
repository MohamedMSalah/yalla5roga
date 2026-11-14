import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/presentation/widgets/discover_selected_place_action.dart';
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
  });
  final SuggestedPlace place;
  final String category, vibes;
  final double? distanceKm;
  final bool selected;
  final VoidCallback onSelect, onDetails, onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      selected: selected,
      child: Material(
        color: context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Responsive.radiusMd),
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppNetworkImage(
                            url: place.coverImageUrl,
                            width: 68,
                            height: 76,
                            radius: Responsive.radiusSm,
                            placeholderIcon: Icons.place_outlined,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.localizedName(l10n),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.titleSmall,
                                ),
                                Text(
                                  [
                                    category,
                                    if (distanceKm != null)
                                      l10n.catalogKm(
                                        double.parse(
                                          distanceKm!.toStringAsFixed(1),
                                        ),
                                      ),
                                  ].where((v) => v.isNotEmpty).join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.bodySmall,
                                ),
                                if (vibes.isNotEmpty)
                                  Text(
                                    vibes,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.texts.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          SavePlaceButton(place: place),
                          Expanded(
                            child: TextButton(
                              onPressed: onDetails,
                              child: Text(l10n.discoverPlaceDetails),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: DiscoverSelectedPlaceAction(onPressed: onCreate),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
