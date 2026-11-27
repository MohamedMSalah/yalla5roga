import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/entities/meetup_results.dart';
import '../../domain/entities/meetup_session.dart';
import '../../domain/entities/standalone_participant.dart';
import '../../domain/repositories/smart_meetup_repository.dart';
import '../datasources/smart_meetup_remote_datasource.dart';

class SmartMeetupRepositoryImpl implements SmartMeetupRepository {
  const SmartMeetupRepositoryImpl(this._remote, this._network);
  final SmartMeetupRemoteDataSource _remote;
  final NetworkInfo _network;

  @override
  Future<Either<Failure, MeetupResults>> results(
    String account,
    String id, {
    String? calculationId,
  }) => _request(
    () => _remote.results(account, id, calculationId: calculationId),
  );

  @override
  Future<Either<Failure, MeetupResults>> calculate(String account, String id) =>
      _request(() => _remote.calculate(account, id));

  Future<Either<Failure, T>> _request<T>(Future<T> Function() run) async {
    try {
      if (!await _network.isConnected) return const Left(NetworkFailure());
      return Right(await run());
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }

  @override
  Future<Either<Failure, MeetupSession>> open(String account, String groupId) =>
      _request(() => _remote.open(account, groupId));

  @override
  Future<Either<Failure, MeetupSession>> openStandalone(String account) =>
      _request(() => _remote.openStandalone(account));

  @override
  Future<Either<Failure, MeetupSession>> saveParticipant(
    String account,
    String id,
    ManualParticipantDraft draft, {
    String? participantId,
  }) => _request(
    () => _remote.saveParticipant(
      account,
      id,
      draft,
      participantId: participantId,
    ),
  );

  @override
  Future<Either<Failure, MeetupSession>> removeParticipant(
    String account,
    String id,
    String participantId,
  ) => _request(() => _remote.removeParticipant(account, id, participantId));

  @override
  Future<Either<Failure, MeetupSession>> refresh(String account, String id) =>
      _request(() => _remote.refresh(account, id));

  @override
  Future<Either<Failure, MeetupSession>> update(
    String account,
    String id,
    MeetupPreferences preferences,
  ) => _request(() => _remote.update(account, id, preferences));

  @override
  Future<Either<Failure, MeetupSession>> resetPreferences(
    String account,
    String id,
  ) => _request(() => _remote.resetPreferences(account, id));

  @override
  Future<Either<Failure, List<MeetupCategoryOption>>> filterOptions(
    String account,
  ) => _request(() => _remote.filterOptions(account));

  @override
  Future<Either<Failure, MeetupSession>> cancel(String account, String id) =>
      _request(() => _remote.cancel(account, id));
}
