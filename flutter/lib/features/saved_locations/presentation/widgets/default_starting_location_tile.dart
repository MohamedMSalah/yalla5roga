import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';
import 'package:yalla_5roga/features/transportation/presentation/widgets/transportation_mode_selector.dart';

import '../../domain/entities/default_starting_location.dart';

class DefaultStartingLocationTile extends StatelessWidget {
  const DefaultStartingLocationTile({
    super.key,
    required this.location,
    required this.onSelect,
    this.onClear,
    this.onTransportationChanged,
  });

  final DefaultStartingLocation? location;
  final VoidCallback? onSelect;
  final VoidCallback? onClear;
  final ValueChanged<TransportationMode?>? onTransportationChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final selected = location;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.route_outlined,
              color: context.palette.brandStrong,
            ),
            title: Text(l.defaultStartingLocation),
            subtitle: Text(
              selected == null
                  ? l.startingLocationSetupRequired
                  : [
                      selected.name,
                      ?selected.approximateArea,
                      selected.source == StartingLocationSource.savedPlace
                          ? l.startingSavedPlaces
                          : l.myLocations,
                    ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: onSelect != null,
            onTap: onSelect,
          ),
          if (selected?.source == StartingLocationSource.savedPlace)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.transportationLocation,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(l.transportationLocationHint),
                  TransportationModeSelector(
                    value: selected?.preferredTransportationMode,
                    onChanged: onTransportationChanged,
                  ),
                ],
              ),
            ),
          if (selected != null && onClear != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: TextButton(
                  onPressed: onClear,
                  child: Text(l.startingLocationClear),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
