import 'package:yalla_5roga/features/transportation/data/models/transportation_preference_model.dart';

import '../../domain/entities/saved_location.dart';

abstract final class SavedLocationModel {
  static SavedLocation fromJson(Map<String, dynamic> json) => SavedLocation(
    id: json['id'] as String,
    name: json['name'] as String,
    type: SavedLocationType.values.byName(json['location_type'] as String),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    approximateArea: json['approximate_area'] as String?,
    address: json['address'] as String?,
    placeId: json['place_id'] as String?,
    preferredTransportationMode: TransportationPreferenceModel.modeFromJson(
      json['preferred_transportation_mode'],
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  static Map<String, Object?> toJson(SavedLocationDraft draft) => {
    'name': draft.name.trim(),
    'location_type': draft.type.name,
    'latitude': draft.latitude,
    'longitude': draft.longitude,
    'approximate_area': draft.approximateArea?.trim(),
    'address': draft.address?.trim(),
    'place_id': draft.placeId,
    if (draft.clearTransportationPreference ||
        draft.preferredTransportationMode != null)
      ...TransportationPreferenceModel.locationPatch(
        draft.preferredTransportationMode,
      ),
  };
}
