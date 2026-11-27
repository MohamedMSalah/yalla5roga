import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

enum SavedLocationType { home, work, university, gym, custom }

class SavedLocationDraft {
  const SavedLocationDraft({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.approximateArea,
    this.address,
    this.placeId,
    this.preferredTransportationMode,
    this.clearTransportationPreference = false,
  });

  final String name;
  final SavedLocationType type;
  final double latitude;
  final double longitude;
  final String? approximateArea;
  final String? address;
  final String? placeId;
  final TransportationMode? preferredTransportationMode;
  final bool clearTransportationPreference;

  bool get isValid =>
      name.trim().isNotEmpty &&
      name.trim().length <= 100 &&
      (approximateArea?.trim().length ?? 0) <= 100 &&
      (address?.trim().length ?? 0) <= 1000 &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

class SavedLocation extends SavedLocationDraft {
  const SavedLocation({
    required this.id,
    required super.name,
    required super.type,
    required super.latitude,
    required super.longitude,
    super.approximateArea,
    super.address,
    super.placeId,
    super.preferredTransportationMode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
}
