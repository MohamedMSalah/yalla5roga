import '../../domain/entities/location_privacy_settings.dart';

abstract final class LocationPrivacySettingsModel {
  static LocationPrivacySettings fromJson(Map<String, dynamic> json) {
    return LocationPrivacySettings(
      visibility: switch (json['location_visibility']) {
        'APPROXIMATE' => LocationVisibility.approximate,
        'HIDDEN' => LocationVisibility.hidden,
        _ => throw const FormatException('Invalid location visibility'),
      },
      automaticUsageEnabled:
          json['automatic_meetup_location_usage_enabled'] as bool,
      consentAt: switch (json['location_usage_consent_at']) {
        final String date => DateTime.parse(date),
        null => null,
        _ => throw const FormatException('Invalid location consent date'),
      },
      consentPolicyVersion: json['consent_policy_version'] as String?,
      requiredPolicyVersion: json['required_consent_policy_version'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      setupStatus: switch (json['setup_status']) {
        'READY' => LocationSetupStatus.ready,
        'CONSENT_REQUIRED' => LocationSetupStatus.consentRequired,
        'STARTING_LOCATION_REQUIRED' =>
          LocationSetupStatus.startingLocationRequired,
        _ => throw const FormatException('Invalid location setup status'),
      },
    );
  }

  static Map<String, String> visibilityPatch(LocationVisibility visibility) => {
    'location_visibility': switch (visibility) {
      LocationVisibility.approximate => 'APPROXIMATE',
      LocationVisibility.hidden => 'HIDDEN',
    },
  };
}
