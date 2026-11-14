import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/vote_countdown.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_attendance_widget.dart';

const _outingId = '00000000-0000-4000-8000-000000000001';

class _RosterAdapter implements HttpClientAdapter {
  var memberStatus = 'no_response';
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.path.endsWith('/attendance')
        ? [
            {
              'outing_id': _outingId,
              'user_id': 'owner',
              'status': 'going',
              'updated_at': '2030-01-01T00:00:00Z',
              'users': {'name': 'Owner', 'image_url': ''},
            },
            {
              'outing_id': _outingId,
              'user_id': 'member',
              'status': memberStatus,
              'updated_at': memberStatus == 'no_response'
                  ? null
                  : '2030-01-01T01:00:00Z',
              'users': {
                'name': 'Member',
                'image_url': 'https://example.com/avatar.png',
              },
            },
          ]
        : [
            {
              'id': _outingId,
              'title': 'Plan',
              'status': 'confirmed',
              'going': 1,
            },
          ];
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': options.path.endsWith('/$_outingId') ? data.single : data,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  final end = DateTime.utc(2030, 1, 2, 3, 4, 5);
  test('countdown splits days, hours, minutes and seconds', () {
    final value = VoteCountdown(endsAt: end, now: DateTime.utc(2030, 1, 1));
    expect(
      [value.days, value.hours, value.minutes, value.seconds],
      [1, 3, 4, 5],
    );
  });
  test('remaining time follows elapsed wall time and never goes negative', () {
    final initial = end.subtract(const Duration(seconds: 5));
    expect(VoteCountdown(endsAt: end, now: initial).seconds, 5);
    expect(
      VoteCountdown(
        endsAt: end,
        now: initial.add(const Duration(seconds: 3)),
      ).seconds,
      2,
    );
    expect(VoteCountdown(endsAt: end, now: end).ended, isTrue);
    expect(
      VoteCountdown(
        endsAt: end,
        now: end.add(const Duration(days: 1)),
      ).totalSeconds,
      0,
    );
  });
  test(
    'partial final second remains live, while server closure ends early',
    () {
      expect(
        VoteCountdown(
          endsAt: end,
          now: end.subtract(const Duration(milliseconds: 1)),
        ).seconds,
        1,
      );
      expect(
        VoteCountdown(
          endsAt: end,
          now: end.subtract(const Duration(days: 1)),
          isClosed: true,
        ).ended,
        isTrue,
      );
    },
  );
  test('UTC offsets represent the same deadline', () {
    final offset = DateTime.parse('2030-01-02T05:04:05+02:00');
    expect(
      VoteCountdown(
        endsAt: offset,
        now: end.subtract(const Duration(seconds: 1)),
      ).seconds,
      1,
    );
  });
  test('No response is localized and is not a valid submitted RSVP', () {
    const en = L10n(Locale('en'));
    const ar = L10n(Locale('ar'));
    expect(AttendanceDisplay.label(AttendanceStatus.unset, en), 'No response');
    expect(AttendanceDisplay.label(AttendanceStatus.unset, ar), ar.noResponse);
    expect(attendanceStatusFromApi('no_response'), 'unset');
    expect(() => attendanceStatusToApi('unset'), throwsArgumentError);
    expect(en.voteCountdown(1, 2, 3, 4), 'Ends in 1d 02h 03m 04s');
    expect(ar.voteCountdown(1, 2, 3, 4), contains('٠٤'));
  });
  test(
    'authorized RSVP rows populate the roster and preserve unanswered defaults',
    () async {
      final adapter = _RosterAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final remote = OutingsRemoteDataSource(ApiClient(dio));
      await remote.load();
      final snapshot = await remote.reloadOutingDetails(_outingId);
      expect(
        snapshot.attendanceByOuting[_outingId]!['member'],
        AttendanceStatus.unset,
      );
      expect(
        remote.membersForOuting(snapshot.outings.single).map((p) => p.name),
        ['Owner', 'Member'],
      );
      adapter.memberStatus = 'maybe';
      final changed = await remote.reloadOutingDetails(_outingId);
      expect(
        changed.attendanceByOuting[_outingId]!['member'],
        AttendanceStatus.maybe,
      );
      remote.clearCache();
      expect(remote.membersForOuting(changed.outings.single), isEmpty);
      dio.close(force: true);
    },
  );
  test('No response and roster profiles survive cached realtime writes and offline reopening', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final snapshots = OfflineSnapshots(
      prefs,
      () => 'account',
      'https://api.test',
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _RosterAdapter();
    final remote = OutingsRemoteDataSource(
      ApiClient(dio, snapshots: snapshots),
    );
    await remote.load();
    await remote.reloadOutingDetails(_outingId);
    remote.applyAttendanceChange(
      _outingId,
      'owner',
      AttendanceStatus.going,
      DateTime.utc(2031),
    );
    await Future<void>.delayed(Duration.zero);
    final key = snapshots.keyFor(
      ApiConstants.outingAttendance(_outingId),
      null,
    );
    final cached = snapshots.read<Map<String, dynamic>>(key)!;
    final member = (cached['data'] as List).cast<Map>().singleWhere(
      (row) => row['user_id'] == 'member',
    );
    expect(member['status'], 'no_response');
    expect(member['users']['name'], 'Member');
    final reopened = OutingsRemoteDataSource(
      ApiClient(dio, snapshots: snapshots),
    );
    await OfflineSnapshots.preview(reopened.load);
    final loaded = await OfflineSnapshots.preview(
      () => reopened.reloadOutingDetails(_outingId),
    );
    expect(
      loaded.attendanceByOuting[_outingId]!['member'],
      AttendanceStatus.unset,
    );
    expect(reopened.membersForOuting(loaded.outings.single).length, 2);
    dio.close(force: true);
  });
}
