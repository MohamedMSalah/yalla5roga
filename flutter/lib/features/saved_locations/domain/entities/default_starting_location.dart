import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

import 'saved_location.dart';

enum StartingLocationSource { savedLocation, savedPlace }

class DefaultStartingLocation {
  const DefaultStartingLocation({
    required this.source,
    required this.referenceId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.approximateArea,
    this.preferredTransportationMode,
  });

  DefaultStartingLocation.personal(SavedLocation location)
    : this(
        source: StartingLocationSource.savedLocation,
        referenceId: location.id,
        name: location.name,
        latitude: location.latitude,
        longitude: location.longitude,
        approximateArea: location.approximateArea,
        preferredTransportationMode: location.preferredTransportationMode,
      );

  final StartingLocationSource source;
  final String referenceId;
  final String name;
  final double latitude;
  final double longitude;
  final String? approximateArea;

  final TransportationMode? preferredTransportationMode;

  DefaultStartingLocation withTransportation(TransportationMode? mode) =>
      DefaultStartingLocation(
        source: source,
        referenceId: referenceId,
        name: name,
        latitude: latitude,
        longitude: longitude,
        approximateArea: approximateArea,
        preferredTransportationMode: mode,
      );

  bool matches(StartingLocationSource source, String id) =>
      this.source == source && referenceId == id;
}
