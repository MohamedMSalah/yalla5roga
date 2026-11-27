import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/map_location.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/features/discover/presentation/providers/discover_provider.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/pages/saved_location_map_page.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/providers/saved_locations_provider.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/widgets/location_source_selector.dart';

class StartingLocationSourceSelector extends StatelessWidget {
  const StartingLocationSourceSelector({
    super.key,
    required this.enabled,
    required this.onDefault,
    required this.onSelect,
  });

  final bool enabled;
  final VoidCallback onDefault;
  final ValueChanged<LocationSelectionMethod> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.home_outlined),
        title: Text(context.l10n.defaultStartingLocation),
        onTap: enabled ? onDefault : null,
      ),
      LocationSourceSelector(enabled: enabled, onSelect: onSelect),
    ],
  );
}

class SavedLocationPicker extends StatelessWidget {
  const SavedLocationPicker({super.key, required this.onSelect});

  final void Function(String id, String label) onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locations = context.watch<SavedLocationsProvider>();
    if (locations.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (locations.readFailure case final failure?) {
      return AppErrorState(
        message: FailureMessageMapper.localize(failure, l),
        onRetry: locations.refresh,
      );
    }
    if (locations.locations.isEmpty) {
      return AppEmptyState(message: l.savedLocationsEmpty, compact: true);
    }
    return Column(
      children: [
        for (final location in locations.locations)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(location.name),
            onTap: () => onSelect(location.id, location.name),
          ),
      ],
    );
  }
}

class SavedPlacePicker extends StatelessWidget {
  const SavedPlacePicker({super.key, required this.onSelect});

  final void Function(String id, String label) onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final discover = context.watch<DiscoverProvider>();
    if (discover.savedLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (discover.savedFailed) {
      return AppErrorState(
        message: l.savedLoadFailed,
        onRetry: () => discover.loadSavedPlaces(force: true),
      );
    }
    if (discover.savedPlaces.isEmpty) {
      return AppEmptyState(message: l.startingBookmarksEmpty, compact: true);
    }
    return Column(
      children: [
        for (final place in discover.savedPlaces)
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: Text(place.localizedName(l)),
            enabled: place.toOutingPlace().hasCoordinates,
            subtitle: place.toOutingPlace().hasCoordinates
                ? null
                : Text(l.startingCoordinatesUnavailable),
            onTap: place.toOutingPlace().hasCoordinates
                ? () => onSelect(place.id, place.localizedName(l))
                : null,
          ),
      ],
    );
  }
}

abstract final class GPSLocationPicker {
  static Future<({LatLng? point, MapLocationIssue? issue})> pick() =>
      const MapLocation().locate(requestPermission: true);
}

abstract final class MapLocationPicker {
  static Future<LatLng?> pick(BuildContext context, {LatLng? initial}) {
    final session = context.read<SavedLocationsProvider>().session;
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            SavedLocationMapPage(initial: initial, session: session),
      ),
    );
  }
}
