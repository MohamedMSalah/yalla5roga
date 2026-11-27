import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../entities/meetup_preferences.dart';
import '../entities/meetup_results.dart';
import '../entities/meetup_session.dart';
import '../entities/standalone_participant.dart';

abstract interface class SmartMeetupRepository {
  Future<Either<Failure, MeetupResults>> results(
    String account,
    String id, {
    String? calculationId,
  });
  Future<Either<Failure, MeetupResults>> calculate(String account, String id);
  Future<Either<Failure, MeetupSession>> open(String account, String groupId);
  Future<Either<Failure, MeetupSession>> openStandalone(String account);
  Future<Either<Failure, MeetupSession>> refresh(String account, String id);
  Future<Either<Failure, MeetupSession>> update(
    String account,
    String id,
    MeetupPreferences preferences,
  );
  Future<Either<Failure, MeetupSession>> resetPreferences(
    String account,
    String id,
  );
  Future<Either<Failure, List<MeetupCategoryOption>>> filterOptions(
    String account,
  );
  Future<Either<Failure, MeetupSession>> cancel(String account, String id);
  Future<Either<Failure, MeetupSession>> saveParticipant(
    String account,
    String id,
    ManualParticipantDraft draft, {
    String? participantId,
  });
  Future<Either<Failure, MeetupSession>> removeParticipant(
    String account,
    String id,
    String participantId,
  );
}
