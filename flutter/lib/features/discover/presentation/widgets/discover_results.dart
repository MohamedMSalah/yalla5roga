import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/maps/location_repository.dart';
import 'package:yalla_5roga/core/maps/location_search_provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/map_controls.dart';
import 'package:yalla_5roga/core/widgets/section_header.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';

class DiscoverPlacesResults extends StatelessWidget {
  const DiscoverPlacesResults({
    super.key,
    required this.places,
    required this.title,
    required this.emptyMessage,
    this.selectedId,
    required this.onSelect,
    required this.onPlan,
  });
  final List<SuggestedPlace> places;
  final String title, emptyMessage;
  final String? selectedId;
  final ValueChanged<SuggestedPlace> onSelect, onPlan;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        if (places.isEmpty)
          AppEmptyState(
            message: emptyMessage,
            icon: Icons.travel_explore,
            compact: true,
          ),
        for (final place in places)
          MapSelectedLocationCard(
            title: place.name,
            subtitle:
                '${place.area} · ${l10n.priceLevelLabel(place.priceLevel.name)}'
                '${place.distanceKm == null ? '' : ' · ${l10n.digits(place.distanceKm!.toStringAsFixed(1))} ${l10n.kilometersShort}'}',
            imageUrl: place.coverImageUrl,
            selected: selectedId == place.id,
            onTap: () => onSelect(place),
            trailing: IconButton(
              tooltip: l10n.createOutingAt(place.name),
              icon: const Icon(Icons.add),
              onPressed: () => onPlan(place),
            ),
          ),
      ],
    );
  }
}

class DiscoverLocationResults extends StatelessWidget {
  const DiscoverLocationResults({
    super.key,
    required this.search,
    required this.onRetry,
    required this.onChoose,
    this.busy = false,
  });
  final LocationSearchProvider search;
  final VoidCallback onRetry;
  final ValueChanged<LocationHit> onChoose;
  final bool busy;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (search.failed)
        ListTile(
          title: Text(context.l10n.mapLookupFailed),
          trailing: IconButton(
            tooltip: context.l10n.tryAgain,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ),
      for (final hit in search.hits)
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: Text(hit.name),
          subtitle: Text(hit.area),
          onTap: busy ? null : () => onChoose(hit),
        ),
      if (search.attribution case final credit?)
        Text(credit, style: context.texts.labelSmall),
    ],
  );
}
