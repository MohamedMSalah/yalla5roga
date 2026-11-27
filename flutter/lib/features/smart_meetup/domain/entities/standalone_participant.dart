import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

class ManualParticipantDraft {
  const ManualParticipantDraft({
    required this.latitude,
    required this.longitude,
    this.displayName,
    this.approximateArea,
    this.transportation,
  });

  final double latitude, longitude;
  final String? displayName, approximateArea;
  final TransportationMode? transportation;
}

class StandaloneParticipant {
  const StandaloneParticipant({
    required this.id,
    required this.isOwner,
    this.displayName,
    this.approximateArea,
    this.latitude,
    this.longitude,
    this.transportation,
  });

  final String id;
  final bool isOwner;
  final String? displayName, approximateArea;
  final double? latitude, longitude;
  final TransportationMode? transportation;
}
