import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

class _Network implements NetworkInfo {
  bool online = true;

  @override
  Future<bool> get isConnected async => online;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'transport failure serves saved data and requests a later synchronization',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = OfflineSnapshots(prefs, () => 'alice', 'backend');
      const path = '/api/outings/cuser';
      await store.write(store.keyFor(path, null)!, {
        'data': ['saved'],
      }, store.generation);
      final dio = Dio();
      addTearDown(dio.close);
      var retries = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              ),
            );
          },
        ),
      );
      final api = ApiClient(
        dio,
        snapshots: store,
        networkInfo: _Network(),
        onReadFailure: () => retries++,
      );
      final response = await api.get<Map<String, dynamic>>(path);
      expect(response.data?['data'], ['saved']);
      expect(retries, 1);
    },
  );

  test(
    'cleared session rejects an old response and backend origins stay isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = OfflineSnapshots(prefs, () => 'alice', 'backend');
      const path = '/api/groups/cuser';
      final key = store.keyFor(path, null)!;
      final generation = store.generation;
      await store.write(key, {
        'data': ['alice'],
      }, generation);
      final other = OfflineSnapshots(prefs, () => 'alice', 'other-backend');
      expect(other.read<Map>(other.keyFor(path, null)), isNull);
      await store.clear('alice');
      await store.write(key, {
        'data': ['late'],
      }, generation);
      expect(store.read<Map>(key), isNull);
    },
  );

  test(
    'preview uses disk, reconnect replaces it, and access denial evicts it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      String? uid = 'alice';
      const origin = 'https://example.test';
      const path = '/api/groups/cuser';
      final network = _Network();
      final dio = Dio();
      var requests = 0;
      var status = 200;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            final response = Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: status,
              data: {
                'data': [requests],
              },
            );
            if (status == 200) {
              handler.resolve(response);
            } else {
              handler.reject(
                DioException.badResponse(
                  statusCode: status,
                  requestOptions: options,
                  response: response,
                ),
              );
            }
          },
        ),
      );
      OfflineSnapshots store() => OfflineSnapshots(prefs, () => uid, origin);
      ApiClient client() =>
          ApiClient(dio, snapshots: store(), networkInfo: network);
      Future<Object?> read(ApiClient api) async =>
          (await api.get<Map<String, dynamic>>(path)).data?['data'];

      expect(await read(client()), [1]);
      expect(await OfflineSnapshots.preview(() => read(client())), [1]);
      network.online = false;
      expect(await read(client()), [1]);
      expect(requests, 1);

      uid = 'bob';
      await expectLater(read(client()), throwsA(isA<DioException>()));
      uid = 'alice';
      network.online = true;
      expect(await read(client()), [2]);
      status = 403;
      await expectLater(read(client()), throwsA(isA<DioException>()));
      network.online = false;
      await expectLater(
        read(client()),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'error',
            isA<NetworkException>(),
          ),
        ),
      );
      expect(requests, 3);
    },
  );
}
