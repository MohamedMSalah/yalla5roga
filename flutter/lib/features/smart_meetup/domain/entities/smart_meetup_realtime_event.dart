enum SmartMeetupChange {
  sessionUpdated('SESSION_UPDATED'),
  sessionExpired('SESSION_EXPIRED'),
  readinessChanged('READINESS_CHANGED'),
  preferencesChanged('PREFERENCES_CHANGED'),
  resultsInvalidated('RESULTS_INVALIDATED'),
  calculationCompleted('CALCULATION_COMPLETED'),
  subscriptionRevoked(null);

  const SmartMeetupChange(this.wireValue);
  final String? wireValue;

  String get topic =>
      'smart_meetup:${(wireValue ?? 'SUBSCRIPTION_REVOKED').toLowerCase()}';
}

class SmartMeetupRealtimeEvent {
  const SmartMeetupRealtimeEvent({
    required this.sessionId,
    required this.change,
    this.inputVersion,
    this.calculationAttempt,
  });

  final String sessionId;
  final SmartMeetupChange change;
  final int? inputVersion;
  final int? calculationAttempt;

  static SmartMeetupRealtimeEvent? fromMessage(
    SmartMeetupChange change,
    Map<String, dynamic> payload,
  ) {
    final sessionId = payload['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) return null;
    if (change == SmartMeetupChange.subscriptionRevoked) {
      return SmartMeetupRealtimeEvent(sessionId: sessionId, change: change);
    }
    final version = payload['inputVersion'];
    final attempt = payload['calculationAttempt'];
    if (payload['changeType'] != change.wireValue ||
        version is! int ||
        version < 1) {
      return null;
    }
    final calculationEvent =
        change == SmartMeetupChange.resultsInvalidated ||
        change == SmartMeetupChange.calculationCompleted;
    if (calculationEvent && (attempt is! int || attempt < 1)) return null;
    return SmartMeetupRealtimeEvent(
      sessionId: sessionId,
      change: change,
      inputVersion: version,
      calculationAttempt: attempt is int ? attempt : null,
    );
  }
}
