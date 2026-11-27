import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

enum LocationSelectionMethod { personal, bookmark, gps, map }

class LocationSourceSelector extends StatelessWidget {
  const LocationSourceSelector({
    super.key,
    required this.onSelect,
    this.enabled = true,
    this.sources = LocationSelectionMethod.values,
  });

  final ValueChanged<LocationSelectionMethod> onSelect;
  final bool enabled;
  final List<LocationSelectionMethod> sources;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        for (final method in sources)
          ListTile(
            enabled: enabled,
            leading: Icon(switch (method) {
              LocationSelectionMethod.personal => Icons.location_on_outlined,
              LocationSelectionMethod.bookmark => Icons.bookmark_border,
              LocationSelectionMethod.gps => Icons.my_location,
              LocationSelectionMethod.map => Icons.map_outlined,
            }),
            title: Text(switch (method) {
              LocationSelectionMethod.personal => l.myLocations,
              LocationSelectionMethod.bookmark => l.startingSavedPlaces,
              LocationSelectionMethod.gps => l.startingCurrentGps,
              LocationSelectionMethod.map => l.startingPickOnMap,
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelect(method),
          ),
      ],
    );
  }
}
