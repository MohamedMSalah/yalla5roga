import '../../domain/entities/transportation_preference.dart';

abstract final class TransportationPreferenceModel {
  static TransportationMode? modeFromJson(Object? value) =>
      TransportationMode.values.where((mode) => mode.code == value).firstOrNull;

  static TransportationPreference fromJson(Map<String, dynamic> json) =>
      TransportationPreference(
        defaultMode: modeFromJson(json['default_transportation_mode']),
      );

  static Map<String, Object?> accountPatch(TransportationMode? mode) => {
    'default_transportation_mode': mode?.code,
  };

  static Map<String, Object?> locationPatch(TransportationMode? mode) => {
    'preferred_transportation_mode': mode?.code,
  };
}
