import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/smart_meetup/data/models/meetup_preferences_model.dart';
import 'package:yalla_5roga/features/smart_meetup/data/models/meetup_results_model.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_preferences.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_results.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_session.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/smart_meetup_realtime_event.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/repositories/smart_meetup_repository.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/smart_meetup_realtime.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/providers/meetup_results_provider.dart';

void main() {
  late _ResultsFixture repository;
  late MeetupResultsProvider provider;

  setUp(() {
    repository = _ResultsFixture();
    provider = MeetupResultsProvider(repository, 'meetup', 'account', 3);
  });

  tearDown(() => provider.dispose());

  test(
    'current ranked results validate the exact calculation and selection',
    () async {
      await provider.load();
      expect(provider.canConsume, isTrue);
      expect(
        provider.result!.recommendations.single.averageDurationMinutes,
        isNull,
      );
      expect(provider.result!.recommendations.single.matchScore, isNull);
      final selected = await provider.validate({'place'});
      expect(repository.requestedCalculation, 'attempt');
      expect(selected?.single.place.id, 'place');
    },
  );

  test(
    'an input change disables consumption during and after validation',
    () async {
      await provider.load();
      repository.exact = Future.value(
        Right(_result(status: 'STALE', version: 4)),
      );
      final validation = provider.validate({'place'});
      expect(provider.canConsume, isFalse);
      expect(await validation, isNull);
      expect(provider.canConsume, isFalse);
      expect(provider.result?.inputVersion, 4);
    },
  );

  test(
    'expired results and offline in-flight validation block handoff',
    () async {
      repository.latest = _result(expired: true);
      await provider.load();
      expect(provider.hasExpired, isTrue);
      expect(await provider.validate({'place'}), isNull);
      expect(repository.requestedCalculation, isNull);

      repository.latest = _result();
      final inFlight = Completer<Either<Failure, MeetupResults>>();
      repository.exact = inFlight.future;
      await provider.load();
      final validation = provider.validate({'place'});
      provider.setOffline(true);
      inFlight.complete(Right(_result()));
      expect(await validation, isNull);
      expect(provider.canConsume, isFalse);
    },
  );

  test(
    'an account change clears the result and ignores a delayed reply',
    () async {
      final inFlight = Completer<Either<Failure, MeetupResults>>();
      repository.exact = inFlight.future;
      await provider.load();
      final validation = provider.validate({'place'});
      provider.accountChanged('other');
      inFlight.complete(Right(_result()));
      expect(await validation, isNull);
      expect(provider.result, isNull);
      expect(provider.failure, isA<AuthFailure>());
    },
  );

  test(
    'duplicate invalidation cannot restore or repeatedly fetch old results',
    () async {
      provider.dispose();
      final realtime = _RealtimeFixture();
      provider = MeetupResultsProvider(
        repository,
        'meetup',
        'account',
        3,
        realtime: realtime,
      )..setActive(true);
      await provider.load();
      final delayed = Completer<Either<Failure, MeetupResults>>();
      repository.inFlight = delayed.future;
      final older = provider.load();
      const invalidated = SmartMeetupRealtimeEvent(
        sessionId: 'meetup',
        change: SmartMeetupChange.resultsInvalidated,
        inputVersion: 3,
        calculationAttempt: 1,
      );
      realtime.emit(invalidated);
      realtime.emit(invalidated);
      expect(provider.isStale, isTrue);
      expect(provider.canConsume, isFalse);
      repository.inFlight = null;
      repository.latest = _result(status: 'STALE');
      delayed.complete(Right(_result()));
      await older;
      expect(provider.isStale, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(provider.result?.status, MeetupCalculationStatus.stale);
      expect(repository.reads, 3);

      repository.latest = _result(attempt: 2);
      const completed = SmartMeetupRealtimeEvent(
        sessionId: 'meetup',
        change: SmartMeetupChange.calculationCompleted,
        inputVersion: 3,
        calculationAttempt: 2,
      );
      realtime.emit(completed);
      realtime.emit(invalidated);
      realtime.emit(completed);
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.reads, 4);
      expect(provider.result?.calculation?.attempt, 2);
      expect(provider.canConsume, isTrue);

      provider.setActive(false);
      expect(realtime.isSubscribed, isFalse);
      provider.setActive(true);
      realtime.joined(3);
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(repository.reads, 5);

      realtime.emit(
        const SmartMeetupRealtimeEvent(
          sessionId: 'meetup',
          change: SmartMeetupChange.sessionExpired,
          inputVersion: 4,
        ),
      );
      expect(provider.sessionStatus, MeetupSessionStatus.expired);
      expect(provider.result, isNull);
      expect(realtime.isSubscribed, isFalse);
    },
  );
}

MeetupResults _result({
  String status = 'READY',
  int version = 3,
  int attempt = 1,
  bool expired = false,
}) {
  final now = DateTime.now();
  return MeetupResultsModel.fromJson({
    'status': status,
    'inputVersion': version,
    'intendedParticipantCount': 1,
    'includedParticipantCount': 1,
    'unavailableParticipantCount': 0,
    'isPartial': false,
    'preferences': MeetupPreferencesModel.toJson(const MeetupPreferences()),
    'calculation': {
      'id': 'attempt',
      'inputVersion': 3,
      'attempt': attempt,
      'optimizationPolicyVersion': '1',
      'calculatedAt': now
          .subtract(const Duration(minutes: 2))
          .toIso8601String(),
      'expiresAt': now
          .add(Duration(minutes: expired ? -1 : 1))
          .toIso8601String(),
    },
    'recommendations': [
      if (status == 'READY')
        {
          'rank': 1,
          'placeId': 'place',
          'place': {'id': 'place', 'name': 'Venue'},
          'budgetLevel': 'AFFORDABLE',
          'averageRating': 4.5,
          'ratingCount': 2,
          'explanationCodes': ['MATCHES_BUDGET'],
        },
    ],
  });
}

class _ResultsFixture implements SmartMeetupRepository {
  MeetupResults latest = _result();
  Future<Either<Failure, MeetupResults>>? exact;
  String? requestedCalculation;
  Future<Either<Failure, MeetupResults>>? inFlight;
  int reads = 0;

  @override
  Future<Either<Failure, MeetupResults>> results(
    String account,
    String id, {
    String? calculationId,
  }) async {
    expect(account, 'account');
    expect(id, 'meetup');
    requestedCalculation = calculationId;
    if (calculationId != null && exact != null) return exact!;
    reads++;
    if (inFlight != null) return inFlight!;
    return Right(latest);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RealtimeFixture
    implements SmartMeetupRealtime, SmartMeetupRealtimeSubscription {
  void Function(SmartMeetupRealtimeEvent)? _onChange;
  void Function(int?, bool)? _onJoined;
  bool get isSubscribed => _onChange != null;

  @override
  SmartMeetupRealtimeSubscription subscribe(
    String account,
    String sessionId, {
    required void Function(SmartMeetupRealtimeEvent) onChange,
    required void Function(int?, bool) onJoined,
  }) {
    _onChange = onChange;
    _onJoined = onJoined;
    return this;
  }

  void emit(SmartMeetupRealtimeEvent event) => _onChange?.call(event);
  void joined(int version) => _onJoined?.call(version, true);

  @override
  void dispose() {
    _onChange = null;
    _onJoined = null;
  }
}
