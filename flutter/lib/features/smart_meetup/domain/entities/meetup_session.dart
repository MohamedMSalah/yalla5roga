import 'meetup_preferences.dart';
import 'standalone_participant.dart';

enum MeetupSessionStatus { active, cancelled, expired }

enum MeetupCalculationStatus {
  routingUnavailable,
  insufficientData,
  queued,
  calculating,
  ready,
  partial,
  stale,
  failed,
  noMatchingVenues,
}

enum MeetupReadinessStatus { ready, partial, insufficientData }

class MeetupParticipantReadiness {
  const MeetupParticipantReadiness({
    required this.name,
    required this.isSelf,
    required this.ready,
    required this.district,
    this.requestTargetUserId,
  });

  final String name;
  final bool isSelf;
  final bool ready;
  final String? district;
  final String? requestTargetUserId;
}

class MeetupReadinessSummary {
  const MeetupReadinessSummary({
    required this.intended,
    required this.usable,
    required this.requiringSetup,
    required this.status,
    required this.participants,
  });

  final int intended;
  final int usable;
  final int requiringSetup;
  final MeetupReadinessStatus status;
  final List<MeetupParticipantReadiness> participants;
}

class MeetupSession {
  const MeetupSession({
    required this.id,
    required this.status,
    required this.calculation,
    required this.preferences,
    required this.inputVersion,
    required this.expiresAt,
    required this.canManage,
    required this.readiness,
    this.standaloneParticipants = const [],
    this.manualParticipantLimit = 0,
  });

  final String id;
  final MeetupSessionStatus status;
  final MeetupCalculationStatus calculation;
  final MeetupPreferences preferences;
  final int inputVersion;
  final DateTime expiresAt;
  final bool canManage;
  final MeetupReadinessSummary? readiness;
  final List<StandaloneParticipant> standaloneParticipants;
  final int manualParticipantLimit;

  MeetupSession closed(MeetupSessionStatus status, int version) =>
      MeetupSession(
        id: id,
        status: status,
        calculation: MeetupCalculationStatus.stale,
        preferences: preferences,
        inputVersion: version,
        expiresAt: expiresAt,
        canManage: false,
        readiness: null,
      );
}
