enum LocationVisibility { approximate, hidden }

enum LocationSetupStatus { ready, consentRequired, startingLocationRequired }

class LocationPrivacySettings {
  const LocationPrivacySettings({
    required this.visibility,
    required this.automaticUsageEnabled,
    required this.consentAt,
    required this.consentPolicyVersion,
    required this.requiredPolicyVersion,
    required this.updatedAt,
    required this.setupStatus,
  });

  static const supportedPolicyVersion = 'smart-meetup-location-v1';

  final LocationVisibility visibility;
  final bool automaticUsageEnabled;
  final DateTime? consentAt;
  final String? consentPolicyVersion;
  final String requiredPolicyVersion;
  final DateTime updatedAt;
  final LocationSetupStatus setupStatus;

  bool get canPresentConsent => requiredPolicyVersion == supportedPolicyVersion;
}
