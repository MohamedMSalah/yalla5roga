import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
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
    final body = handler();
    if (body is ResponseBody) return body;
    return ResponseBody.fromString(
      jsonEncode(body),
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
    'vote_ends_at': ?voteEndsAt,
  };
}

ApiClient _clientFor(_MockAdapter adapter, {OfflineSnapshots? snapshots}) {
  final dio = Dio(
    BaseOptions(baseUrl: 'http://test', responseType: ResponseType.json),
  );
  dio.httpClientAdapter = adapter;
  return ApiClient(dio, snapshots: snapshots);
}

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('complete attendance rows update provider and cache without HTTP or redundant rebuilds', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineSnapshots(prefs, () => 'alice', 'test');
    var serverStatus = 'going';
    var attendanceDenied = false;
    var serverAt = '2026-11-11T10:00:00Z';
    final adapter = _MockAdapter({
      'GET ${ApiConstants.outingsCuser}': () => {
        'data': [_outingJson(id: id, status: 'confirmed')],
      },
      'GET ${ApiConstants.outing(id)}': () => {
        'data': _outingJson(id: id, status: 'confirmed'),
      },
      'GET ${ApiConstants.outingAttendance(id)}': () => attendanceDenied
          ? ResponseBody.fromString(
              '{}',
              403,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            )
          : {
              'data': [
                {
                  'user_id': 'bob',
                  'status': serverStatus,
                  'updated_at': serverAt,
                },
              ],
            },
    });
    final remote = OutingsRemoteDataSource(
      _clientFor(adapter, snapshots: store),
    );
    final provider = OutingsProvider(
      repository: OutingsRepositoryImpl(remote: remote, networkInfo: _Online()),
    );
    addTearDown(provider.dispose);
    await provider.load();
    await provider.refreshLifecycle(outingId: id, forceRefresh: true);
    final requests = adapter.calls.length;
    var rebuilds = 0;
    provider.addListener(() => rebuilds++);
    final at = DateTime.parse('2026-11-11T11:00:00Z');
    expect(
      provider.applyAttendanceChange(id, 'bob', AttendanceStatus.maybe, at),
      isTrue,
    );
    expect(provider.attendanceFor(id, 'bob'), AttendanceStatus.maybe);
    expect(adapter.calls.length, requests);
    expect(rebuilds, 1);
    provider.applyAttendanceChange(id, 'bob', AttendanceStatus.maybe, at);
    provider.applyAttendanceChange(
      id,
      'bob',
      AttendanceStatus.going,
      at.subtract(const Duration(seconds: 1)),
    );
    expect(rebuilds, 1);
    await Future<void>.delayed(Duration.zero);
    final cached = store.read<Map<String, dynamic>>(
      store.keyFor(ApiConstants.outingAttendance(id), null),
    );
    expect((cached!['data'] as List).single['status'], 'maybe');
    final cold = OutingsRemoteDataSource(_clientFor(adapter, snapshots: store));
    final preview = await OfflineSnapshots.preview(
      () => cold.reloadOutingDetails(id),
    );
    expect(preview.attendanceByOuting[id]?['bob'], AttendanceStatus.maybe);
    expect(adapter.calls.length, requests);
    // A normal cached load and a stale REST row cannot undo the live event.
    await provider.load(forceRefresh: true);
    expect(provider.attendanceFor(id, 'bob'), AttendanceStatus.maybe);
    await provider.refreshLifecycle(outingId: id, forceRefresh: true);
    expect(provider.attendanceFor(id, 'bob'), AttendanceStatus.maybe);
    serverAt = '2026-11-11T12:00:00Z';
    serverStatus = 'not_going';
    await provider.refreshLifecycle(outingId: id, forceRefresh: true);
    expect(provider.attendanceFor(id, 'bob'), AttendanceStatus.notGoing);
    // Narrower attendance authorization can disappear while chat remains readable.
    attendanceDenied = true;
    await provider.refreshLifecycle(outingId: id, forceRefresh: true);
    expect(provider.attendanceFor(id, 'bob'), AttendanceStatus.unset);
  });

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
      expect(provider.byId('not-yet-loaded').id, 'not-yet-loaded');

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
      'GET ${ApiConstants.outingVotingState(votingId)}': () => {
        'success': true,
        'data': {
          'outing': _outingJson(
            id: votingId,
            status: 'voting',
            voteEndsAt: endsAt,
          ),
          'my_option_id': 'opt-1',
          'options': [
            {
              'id': 'opt-1',
              'place_id': 'p1',
              'label': 'Place A',
              'vote_count': 1,
            },
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
    expect(snapshot.votesByOuting[votingId]?.cuserOptionId, 'opt-1');
    expect(snapshot.votesByOuting[votingId]?.options.single.votes, 1);
    expect(snapshot.votesByOuting.containsKey(pastId), isFalse);
    expect(snapshot.attendanceByOuting.containsKey(draftId), isFalse);

    expect(adapter.calls.where((c) => c.contains(pastId)), isEmpty);
    expect(adapter.calls.where((c) => c.contains(draftId)), isEmpty);
    expect(
      adapter.calls.where(
        (call) => call == 'GET ${ApiConstants.outingVotingState(votingId)}',
      ),
      hasLength(1),
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
      'GET ${ApiConstants.outingVotingState(outingId)}': () => {
        'success': true,
        'data': {
          'outing': _outingJson(
            id: outingId,
            status: 'voting',
            voteEndsAt: endsAt,
          ),
          'options': [
            {'id': 'opt-1', 'place_id': 'p1', 'label': 'A'},
            {'id': 'opt-2', 'place_id': 'p2', 'label': 'B'},
          ],
        },
      },
      'GET ${ApiConstants.outingVotingState('other')}': () => {
        'success': true,
        'data': {
          'outing': _outingJson(
            id: 'other',
            status: 'voting',
            voteEndsAt: endsAt,
          ),
          'options': [
            {'id': 'opt-x', 'place_id': 'px', 'label': 'X'},
          ],
        },
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

  test(
    'attendance uses the write response and keeps a second outing untouched',
    () async {
      const outingId = 'c1';
      const other = 'c2';
      final adapter = _MockAdapter({
        'GET ${ApiConstants.outingsCuser}': () => {
          'success': true,
          'data': [
            _outingJson(id: outingId, status: 'confirmed'),
            _outingJson(id: other, status: 'confirmed'),
          ],
        },
        'PUT ${ApiConstants.outingAttendance(outingId)}': () => {
          'success': true,
          'data': {'user_id': 'me', 'status': 'maybe'},
          'items': [
            {'user_id': 'me', 'status': 'maybe'},
            {'user_id': 'other-user', 'status': 'not_going'},
          ],
        },
      });

      final ds = OutingsRemoteDataSource(_clientFor(adapter));
      await ds.load();
      adapter.calls.clear();
      final snapshot = await ds.setAttendance(
        outingId: outingId,
        memberId: 'me',
        status: AttendanceStatus.maybe,
      );

      expect(
        snapshot.attendanceByOuting[outingId]?['me'],
        AttendanceStatus.maybe,
      );
      expect(
        snapshot.attendanceByOuting[outingId]?['other-user'],
        AttendanceStatus.notGoing,
      );
      expect(snapshot.attendanceByOuting[other], isNull);
      expect(adapter.calls, ['PUT ${ApiConstants.outingAttendance(outingId)}']);
    },
  );

  test(
    'RSVP changes optimistically and rolls back after a failed write',
    () async {
      const id = 'rollback';
      final adapter = _MockAdapter({
        'GET ${ApiConstants.outingsCuser}': () => {
          'data': [_outingJson(id: id, status: 'confirmed')],
        },
        'GET ${ApiConstants.outing(id)}': () => {
          'data': _outingJson(id: id, status: 'confirmed'),
        },
        'GET ${ApiConstants.outingAttendance(id)}': () => {
          'data': [
            {'user_id': 'me', 'status': 'going'},
          ],
        },
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final started = Completer<void>();
      final release = Completer<void>();
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.method != 'PUT') {
              handler.next(options);
              return;
            }
            requests++;
            started.complete();
            await release.future;
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 503),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      final provider = OutingsProvider(
        repository: OutingsRepositoryImpl(
          remote: OutingsRemoteDataSource(ApiClient(dio)),
          networkInfo: _Online(),
        ),
      );
      addTearDown(provider.dispose);
      addTearDown(dio.close);
      await provider.load();
      await provider.refreshLifecycle(outingId: id);
      expect(provider.attendanceFor(id, 'me'), AttendanceStatus.going);

      final change = provider.setAttendance(id, 'me', AttendanceStatus.maybe);
      await started.future;
      expect(provider.attendanceFor(id, 'me'), AttendanceStatus.maybe);
      expect(
        await provider.setAttendance(id, 'me', AttendanceStatus.notGoing),
        isFalse,
      );
      expect(requests, 1);
      release.complete();
      expect(await change, isFalse);
      expect(provider.attendanceFor(id, 'me'), AttendanceStatus.going);
    },
  );
}
