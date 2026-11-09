import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/outings/data/repositories/outings_repository_impl.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outings_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handlers);

  final Map<String, dynamic Function()> handlers;
  final calls = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    final handler = handlers[key];
    if (handler == null) {
      return ResponseBody.fromString(
        '{"message":"missing $key"}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(handler()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _outingJson({
  required String id,
  required String status,
  String? voteEndsAt,
}) {
  return {
    'id': id,
    'title': 'Outing $id',
    'status': status,
    'going': 1,
    if (voteEndsAt != null) 'vote_ends_at': voteEndsAt,
  };
}

ApiClient _clientFor(_MockAdapter adapter) {
  final dio = Dio(
    BaseOptions(baseUrl: 'http://test', responseType: ResponseType.json),
  );
  dio.httpClientAdapter = adapter;
  return ApiClient(dio);
}

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  test(
    'confirmed deletion removes the outing even if a stale list arrives',
    () async {
      const id = 'to-delete';
      final adapter = _MockAdapter({
        'GET ${ApiConstants.outingsCuser}': () => {
          'success': true,
          'data': [
            _outingJson(id: id, status: 'draft'),
            _outingJson(id: 'keep', status: 'draft'),
          ],
        },
        'DELETE ${ApiConstants.outing(id)}': () => {
          'success': true,
          'data': _outingJson(id: id, status: 'draft'),
        },
      });
      final provider = OutingsProvider(
        repository: OutingsRepositoryImpl(
          remote: OutingsRemoteDataSource(_clientFor(adapter)),
          networkInfo: _Online(),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load();
      expect(provider.findById(id), isNotNull);

      expect(await provider.delete(id), isTrue);
      expect(adapter.calls, contains('DELETE ${ApiConstants.outing(id)}'));
      expect(provider.findById(id), isNull);
      await provider.load(forceRefresh: true);
      expect(provider.outings.map((outing) => outing.id), ['keep']);
    },
  );

  test('load hydrates only voting outings and skips past/draft', () async {
    const votingId = 'vote-1';
    const pastId = 'past-1';
    const draftId = 'draft-1';
    final endsAt = DateTime.now()
        .add(const Duration(hours: 2))
        .toIso8601String();

    final adapter = _MockAdapter({
      'GET ${ApiConstants.outingsCuser}': () => {
        'success': true,
        'data': [
          _outingJson(id: votingId, status: 'voting', voteEndsAt: endsAt),
          _outingJson(id: pastId, status: 'past'),
          _outingJson(id: draftId, status: 'draft'),
        ],
      },
      'GET ${ApiConstants.outingVoteOptions(votingId)}': () => {
        'success': true,
        'data': {
          'items': [
            {'id': 'opt-1', 'place_id': 'p1', 'label': 'Place A'},
          ],
        },
      },
      'GET ${ApiConstants.outingVotes(votingId)}': () => {
        'success': true,
        'data': {
          'items': [
            {'option_id': 'opt-1', 'user_id': 'u1'},
          ],
        },
      },
      'GET ${ApiConstants.outingAttendance(votingId)}': () => {
        'success': true,
        'data': {
          'items': [
            {'user_id': 'u1', 'status': 'going'},
          ],
        },
      },
    });

    final ds = OutingsRemoteDataSource(_clientFor(adapter));
    final snapshot = await ds.load();

    expect(snapshot.outings.length, 3);
    expect(snapshot.votesByOuting.containsKey(votingId), isTrue);
    expect(snapshot.votesByOuting.containsKey(pastId), isFalse);
    expect(snapshot.attendanceByOuting.containsKey(draftId), isFalse);

    expect(adapter.calls.where((c) => c.contains(pastId)), isEmpty);
    expect(adapter.calls.where((c) => c.contains(draftId)), isEmpty);
    expect(
      adapter.calls.contains('GET ${ApiConstants.outingVotingState(votingId)}'),
      isFalse,
    );
  });

  test('selectVote reloads one outing instead of full cuser fan-out', () async {
    const outingId = 'vote-1';
    final endsAt = DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String();

    final adapter = _MockAdapter({
      'GET ${ApiConstants.outingsCuser}': () => {
        'success': true,
        'data': [
          _outingJson(id: outingId, status: 'voting', voteEndsAt: endsAt),
          _outingJson(id: 'other', status: 'voting', voteEndsAt: endsAt),
        ],
      },
      'GET ${ApiConstants.outingVoteOptions(outingId)}': () => {
        'success': true,
        'data': {
          'items': [
            {'id': 'opt-1', 'place_id': 'p1', 'label': 'A'},
            {'id': 'opt-2', 'place_id': 'p2', 'label': 'B'},
          ],
        },
      },
      'GET ${ApiConstants.outingVoteOptions('other')}': () => {
        'success': true,
        'data': {
          'items': [
            {'id': 'opt-x', 'place_id': 'px', 'label': 'X'},
          ],
        },
      },
      'GET ${ApiConstants.outingVotes(outingId)}': () => {
        'success': true,
        'data': {'items': <Map<String, dynamic>>[]},
      },
      'GET ${ApiConstants.outingVotes('other')}': () => {
        'success': true,
        'data': {'items': <Map<String, dynamic>>[]},
      },
      'GET ${ApiConstants.outingAttendance(outingId)}': () => {
        'success': true,
        'data': {'items': <Map<String, dynamic>>[]},
      },
      'GET ${ApiConstants.outingAttendance('other')}': () => {
        'success': true,
        'data': {'items': <Map<String, dynamic>>[]},
      },
      'POST ${ApiConstants.outingVotes(outingId)}': () => {
        'success': true,
        'data': <String, dynamic>{},
      },
    });

    final ds = OutingsRemoteDataSource(_clientFor(adapter));
    await ds.load();
    final before = adapter.calls.length;
    adapter.calls.clear();

    final snapshot = await ds.selectVote(outingId, 0);
    expect(snapshot.outings.any((o) => o.id == outingId), isTrue);
    expect(adapter.calls.contains('GET ${ApiConstants.outingsCuser}'), isFalse);
    expect(adapter.calls.any((c) => c.contains('/other/')), isFalse);
    expect(adapter.calls.length, lessThan(before));
    expect(
      adapter.calls.contains('POST ${ApiConstants.outingVotes(outingId)}'),
      isTrue,
    );
  });

  test('setAttendance refreshes only that outing attendance', () async {
    const outingId = 'c1';
    final adapter = _MockAdapter({
      'GET ${ApiConstants.outingsCuser}': () => {
        'success': true,
        'data': [_outingJson(id: outingId, status: 'confirmed')],
      },
      'PUT ${ApiConstants.outingAttendance(outingId)}': () => {
        'success': true,
        'data': <String, dynamic>{},
      },
      'GET ${ApiConstants.outingAttendance(outingId)}': () => {
        'success': true,
        'data': {
          'items': [
            {'user_id': 'me', 'status': 'going'},
          ],
        },
      },
    });

    final ds = OutingsRemoteDataSource(_clientFor(adapter));
    await ds.load();
    adapter.calls.clear();

    final snapshot = await ds.setAttendance(
      outingId: outingId,
      memberId: 'me',
      status: AttendanceStatus.going,
    );

    expect(
      snapshot.attendanceByOuting[outingId]?['me'],
      AttendanceStatus.going,
    );
    expect(adapter.calls.contains('GET ${ApiConstants.outingsCuser}'), isFalse);
  });
}
