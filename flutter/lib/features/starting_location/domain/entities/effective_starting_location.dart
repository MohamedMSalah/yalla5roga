import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

enum StartingLocationContext { meetup, outing }

typedef StartingLocationScope = ({StartingLocationContext context, String id});

enum OverrideLocationSource {
  defaultLocation('DEFAULT'),
  personal('PERSONAL_LOCATION'),
  savedPlace('SAVED_PLACE'),
  point('MANUAL_POINT');

  const OverrideLocationSource(this.code);
  final String code;
}

enum EffectiveLocationStatus {
  ready('READY'),
  consentRequired('CONSENT_REQUIRED'),
  excluded('GROUP_EXCLUDED'),
  missing('STARTING_LOCATION_REQUIRED');

  const EffectiveLocationStatus(this.code);
  final String code;
}

class StartingLocationOverride {
  const StartingLocationOverride({
    required this.source,
    this.referenceId,
    this.point,
    this.transportation,
  });

  final OverrideLocationSource source;
  final String? referenceId;
  final LatLng? point;
  final TransportationMode? transportation;
}

class EffectiveStartingLocation {
  const EffectiveStartingLocation({
    required this.status,
    required this.consentPolicyVersion,
    required this.inputVersion,
    this.override,
    this.point,
    this.name,
    this.arabicName,
    this.temporaryLocation = false,
    this.transportation,
    this.temporaryTransportation = false,
    this.expiresAt,
  });

  final EffectiveLocationStatus status;
  final String consentPolicyVersion;
  final int inputVersion;
  final StartingLocationOverride? override;
  final LatLng? point;
  final String? name;
  final String? arabicName;
  final bool temporaryLocation;
  final TransportationMode? transportation;
  final bool temporaryTransportation;
  final DateTime? expiresAt;
}
