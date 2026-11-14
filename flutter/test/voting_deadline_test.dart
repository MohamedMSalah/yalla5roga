import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/voting_deadline.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';

class _CreateAdapter implements HttpClientAdapter {
  Map<String, dynamic>? submitted;
  late Map<String, dynamic> created;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') {
      submitted = Map<String, dynamic>.from(options.data as Map);
      created = {'id': 'canonical-id', ...submitted!, 'status': 'confirmed'};
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': options.method == 'POST' ? created : [created],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  const group = Group(
    id: 'group',
    name: 'Friends',
    outings: 0,
    image: '',
    members: [],
  );
  const l10n = L10n(Locale('en'));
  DateTime reference() => DateTime(2030, 1, 10, 10);
  CreateOutingProvider form(DateTime Function() now) => CreateOutingProvider(
    groups: const [group],
    contacts: const [],
    catalogPlaces: const [],
    specialEventImage: (_) => '',
    group: group,
    now: now,
  );

  test(
    'all requested presets resolve elapsed hours across an offset instant',
    () {
      final now = DateTime.parse('2030-01-10T10:00:00+02:00');
      for (final hours in [1, 2, 3, 6, 12, 24, 48, 72, 120, 168]) {
        final deadline = VotingDeadlinePolicy.endsAt(now, hours);
        expect(deadline.isUtc, isTrue);
        expect(deadline.difference(now), Duration(hours: hours));
        expect(
          VotingDeadlinePolicy.validate(
            now: now,
            hours: hours,
            scheduledAt: now.add(const Duration(days: 8)),
          ),
          isNull,
        );
      }
    },
  );
  test('rejects equal or later deadlines and invalid durations', () {
    final now = reference();
    for (final start in [
      now.add(const Duration(hours: 3)),
      now.add(const Duration(hours: 2)),
    ]) {
      expect(
        VotingDeadlinePolicy.validate(now: now, hours: 3, scheduledAt: start),
        VotingDeadlineProblem.afterOutingStart,
      );
    }
    expect(
      VotingDeadlinePolicy.validate(now: now, hours: 0),
      VotingDeadlineProblem.unsupportedDuration,
    );
    expect(
      VotingDeadlinePolicy.validate(now: now, hours: 169),
      VotingDeadlineProblem.unsupportedDuration,
    );
    expect(
      VotingDeadlinePolicy.validateInstant(now: now, deadline: now),
      VotingDeadlineProblem.notFuture,
    );
  });
  test('duration survives wizard edits and saved draft restoration', () {
    final first = form(reference);
    addTearDown(first.dispose);
    first.nameController.text = 'Weekend plan';
    first.setDate(reference().add(const Duration(days: 10)));
    first.setDeadlineUnit(VotingDeadlineUnit.days);
    first.setVoteDeadlineHours(168);
    expect(first.next(l10n), isNull);
    first.back();
    expect(first.voteDeadlineHours, 168);
    expect(first.deadlineUnit, VotingDeadlineUnit.days);
    final restored = CreateOutingProvider(
      groups: const [group],
      contacts: const [],
      catalogPlaces: const [],
      specialEventImage: (_) => '',
      draft: first.toDraft(),
      now: reference,
    );
    addTearDown(restored.dispose);
    expect(restored.voteDeadlineHours, 168);
  });
  test(
    'schedule edits and time passage revalidate without changing selection',
    () {
      var now = reference();
      final value = form(() => now);
      addTearDown(value.dispose);
      value.setDate(now);
      value.setTime(const TimeOfDay(hour: 14, minute: 0));
      value.setVoteDeadlineHours(3);
      expect(value.isVotingDeadlineValid, isTrue);
      now = now.add(const Duration(hours: 1));
      value.refreshDeadlineClock();
      expect(value.isVotingDeadlineValid, isFalse);
      expect(value.voteDeadlineHours, 3);
      expect(value.validateVotingDeadlineNow(l10n), isNotNull);
      value.setTime(const TimeOfDay(hour: 18, minute: 0));
      expect(value.isVotingDeadlineValid, isTrue);
    },
  );
  test('unit changes retain a single duration and disabled candidates respect start', () {
    final value = form(reference);
    addTearDown(value.dispose);
    value.setDate(reference());
    value.setTime(const TimeOfDay(hour: 14, minute: 0));
    expect(value.canSelectDeadlineHours(6), isFalse);
    expect(value.canSelectDeadlineHours(2), isTrue);
    value.setDeadlineUnit(VotingDeadlineUnit.days);
    expect(value.isVotingDeadlineValid, isFalse);
    value.setDeadlineUnit(VotingDeadlineUnit.hours);
    expect(value.isVotingDeadlineValid, isTrue);
  });
  test(
    'local summaries support English and Arabic number formatting',
    () async {
      await initializeDateFormatting('en');
      await initializeDateFormatting('ar');
      final deadline = DateTime.parse('2030-01-10T18:00:00Z');
      expect(
        l10n.votingDeadlineSummary(deadline),
        contains(l10n.formatTime(deadline.toLocal())),
      );
      const ar = L10n(Locale('ar'));
      expect(
        ar.votingDeadlineSummary(deadline),
        contains(ar.formatTime(deadline.toLocal())),
      );
      expect(ar.votingDurationDays(7), contains('٧'));
    },
  );
  test('POST computes deadline at submission and parses the canonical server instant', () async {
    var now = reference();
    final adapter = _CreateAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final remote = OutingsRemoteDataSource(ApiClient(dio), now: () => now);
    final outing = Outing(
      id: 'local',
      title: 'Weekend plan',
      image: '',
      meta: '',
      date: '',
      status: OutingStatus.confirmed,
      voteDeadlineHours: 120,
      scheduledAt: now.add(const Duration(days: 10)),
    );
    now = now.add(const Duration(minutes: 40));
    final result = await remote.add(outing);
    expect(
      DateTime.parse(adapter.submitted!['vote_ends_at'] as String),
      now.toUtc().add(const Duration(hours: 120)),
    );
    expect(
      result.outing.voteEndsAt,
      DateTime.parse(adapter.created['vote_ends_at'] as String),
    );
    expect(
      result.outing.copyWith(image: 'new-cover').voteEndsAt,
      result.outing.voteEndsAt,
    );
    dio.close(force: true);
  });
  test('a duration invalidated before submission sends no request', () async {
    final now = reference();
    final adapter = _CreateAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final remote = OutingsRemoteDataSource(ApiClient(dio), now: () => now);
    final outing = Outing(
      id: 'local',
      title: 'Weekend plan',
      image: '',
      meta: '',
      date: '',
      voteDeadlineHours: 3,
      scheduledAt: now.add(const Duration(hours: 3)),
    );
    await expectLater(remote.add(outing), throwsA(isA<ServerException>()));
    expect(adapter.submitted, isNull);
    dio.close(force: true);
  });
}
