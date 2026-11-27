import 'package:yalla_5roga/features/transportation/data/models/transportation_preference_model.dart';

import '../../domain/entities/default_starting_location.dart';

abstract final class DefaultStartingLocationModel {
  static DefaultStartingLocation fromJson(Map<String, dynamic> json) =>
      DefaultStartingLocation(
        source: switch (json['source']) {
          'saved_location' => StartingLocationSource.savedLocation,
          'saved_place' => StartingLocationSource.savedPlace,
          _ => throw const FormatException('Unknown starting location source'),
        },
        referenceId: json['reference_id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        approximateArea: json['approximate_area'] as String?,
        preferredTransportationMode: TransportationPreferenceModel.modeFromJson(
          json['preferred_transportation_mode'],
        ),
      );

  static Map<String, Object?> selection(
    StartingLocationSource source,
    String id,
  ) => {
    'source': switch (source) {
      StartingLocationSource.savedLocation => 'saved_location',
      StartingLocationSource.savedPlace => 'saved_place',
    },
    'referenceId': id,
  };
}
