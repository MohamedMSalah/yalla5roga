from pathlib import Path
def edit(path, *pairs):
 p=Path(path); s=p.read_text(encoding='utf-8')
 for a,b in pairs:
  assert a in s, (path,a)
  s=s.replace(a,b,1)
 p.write_text(s,encoding='utf-8')
f='flutter/lib/'
edit(f+'core/network/api_client.dart',
("import 'package:dio/dio.dart';","""import 'dart:async';

import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/network_info.dart';"""),
('const ApiClient(this.dio);','const ApiClient(this.dio, {this.snapshots, this.networkInfo});'),
('  final Dio dio;', '''  final Dio dio;
  final OfflineSnapshots? snapshots;
  final NetworkInfo? networkInfo;'''),
('''  }) {
    return dio.get<T>(path, queryParameters: queryParameters, options: options);
  }''','''  }) async {
    final store = snapshots;
    final key = store?.keyFor(path, queryParameters);
    final generation = store?.generation;
    final request = RequestOptions(path: path);
    Response<T>? cached() {
      final data = store?.read<T>(key);
      return data == null ? null : Response<T>(requestOptions: request, data: data);
    }

    if (OfflineSnapshots.cacheOnly ||
        (key != null && await networkInfo?.isConnected == false)) {
      return cached() ?? (throw DioException(
        requestOptions: request,
        error: const NetworkException(),
        type: DioExceptionType.connectionError,
      ));
    }
    try {
      final response = await dio.get<T>(path, queryParameters: queryParameters, options: options);
      if (key != null) {
        unawaited(store!.write(key, response.data, generation!));
      }
      return response;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (key != null && generation == store!.generation) {
        if (status == 401 || status == 403 || status == 404 || status == 410) {
          await store.remove(key);
        } else if (error.error is NetworkException || (status ?? 0) >= 500) {
          final fallback = cached();
          if (fallback != null) return fallback;
        }
      }
      rethrow;
    }
  }'''))
edit(f+'core/network/remote_guard.dart',
("import 'package:dartz/dartz.dart';","import 'package:dartz/dartz.dart';\nimport 'package:yalla_5roga/core/cache/offline_snapshots.dart';"),
('  ErrorContext? context,','  ErrorContext? context,\n  bool offlineRead = false,'),
('if (!await networkInfo.isConnected)', 'if (!offlineRead && !await networkInfo.isConnected)'),
('  } on AppException catch (error, stack) {','  } on AppException catch (error, stack) {\n    if (OfflineSnapshots.cacheOnly) return Left(ExceptionMapper.toFailure(error));'))
edit(f+'core/cache/cached_remote.dart',
("import 'package:yalla_5roga/core/cache/ttl_cache.dart';","import 'package:yalla_5roga/core/cache/ttl_cache.dart';\nimport 'package:yalla_5roga/core/cache/offline_snapshots.dart';"),
('  bool forceRefresh = false,','  bool forceRefresh = false,\n  bool offlineRead = false,'),
('  final diagnostics', '''  if (OfflineSnapshots.cacheOnly) {
    return guardRemote(networkInfo, fetch, reason: reason, offlineRead: true);
  }
  final diagnostics'''),
('await guardRemote(networkInfo, fetch, reason: reason)','await guardRemote(networkInfo, fetch, reason: reason, offlineRead: offlineRead)'),
('if (allowStaleOnError)', 'if (allowStaleOnError && (failure is NetworkFailure || failure.statusCode != null && failure.statusCode! >= 500))'))
edit(f+'features/groups/data/repositories/groups_repository_impl.dart',
("reason: 'getGroups',","reason: 'getGroups',\n      offlineRead: true,"),
("reason: 'getGroup',\n      feature:", "reason: 'getGroup',\n      offlineRead: true,\n      feature:"))
edit(f+'features/outings/data/repositories/outings_repository_impl.dart',
("reason: 'loadOutings',","reason: 'loadOutings',\n      offlineRead: true,"),
("reason: 'refreshLifecycleOuting',","reason: 'refreshLifecycleOuting',\n        offlineRead: true,"))
