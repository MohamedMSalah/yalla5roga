import 'dart:async';

import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_diagnostics.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_scope.dart';

class ApiClient {
  const ApiClient(
    this.dio, {
    this.snapshots,
    this.networkInfo,
    this.onReadFailure,
  });

  final Dio dio;
  final OfflineSnapshots? snapshots;
  final NetworkInfo? networkInfo;
  final void Function()? onReadFailure;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool useSnapshots = true,
    bool publicRead = false,
  }) async {
    final store = snapshots;
    final key = useSnapshots && !publicRead
        ? store?.keyFor(path, queryParameters)
        : null;
    final generation = store?.generation;
    final uid = publicRead ? null : store?.userId();
    final request = RequestOptions(path: path);
    Response<T>? cached() {
      if (store?.userId() != uid || store?.generation != generation) {
        return null;
      }
      final clock = Stopwatch()..start();
      final data = store?.read<T>(key);
      if (key != null) {
        RequestDiagnostics.instance.recordLocal(
          method: 'GET',
          endpoint: path,
          outcome: data == null
              ? RequestOutcome.cacheMiss
              : RequestOutcome.stale,
          source: 'OfflineSnapshots',
          feature: RequestScope.current?.feature,
          operation: RequestScope.current?.operation,
          durationMs: clock.elapsedMilliseconds,
        );
      }
      return data == null
          ? null
          : Response<T>(requestOptions: request, data: data);
    }

    if (OfflineSnapshots.cacheOnly ||
        ((key != null || publicRead) &&
            await networkInfo?.isConnected == false)) {
      return cached() ??
          (throw DioException(
            requestOptions: request,
            error: const NetworkException(),
            type: DioExceptionType.connectionError,
          ));
    }
    try {
      final bound = publicRead
          ? (options ?? Options()).copyWith(
              extra: {...?options?.extra, publicReadKey: true},
            )
          : uid == null
          ? options
          : (options ?? Options()).copyWith(
              extra: {...?options?.extra, expectedUserIdKey: uid},
            );
      final response = await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: bound,
        cancelToken: cancelToken,
      );
      if (uid != null &&
          (store?.userId() != uid || store?.generation != generation)) {
        throw DioException(
          requestOptions: request,
          error: const AuthException('Account changed'),
        );
      }
      if (key != null) {
        unawaited(store!.write(key, response.data, generation!));
      }
      return response;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (key != null &&
          store?.userId() == uid &&
          generation == store?.generation &&
          (error.error is NetworkException ||
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              status == 408 ||
              status == 429 ||
              (status ?? 0) >= 500)) {
        onReadFailure?.call();
      }
      if (key != null && generation == store!.generation) {
        if (status == 401 || status == 403 || status == 404 || status == 410) {
          if (status == 403 || status == 404 || status == 410) {
            // A detail denial invalidates subresources. A denied subresource
            // (such as attendance for a pending guest) can have narrower access.
            if (path.split('/').length == 4) {
              await store.removeResource(key);
            } else {
              await store.remove(key);
            }
          } else {
            await store.remove(key);
          }
        } else if (error.error is NetworkException ||
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            status == 408 ||
            status == 429 ||
            (status ?? 0) >= 500) {
          final fallback = cached();
          if (fallback != null) return fallback;
        }
      }
      rethrow;
    }
  }

  Options? _writeOptions(Options? options) {
    final uid = snapshots?.userId();
    return uid == null
        ? options
        : (options ?? Options()).copyWith(
            extra: {...?options?.extra, expectedUserIdKey: uid},
          );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.post<T>(
      path,
      data: data,
      options: _writeOptions(options),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(String path, {Object? data, Options? options}) {
    return dio.put<T>(path, data: data, options: _writeOptions(options));
  }

  Future<Response<T>> patch<T>(String path, {Object? data, Options? options}) {
    return dio.patch<T>(path, data: data, options: _writeOptions(options));
  }

  Future<Response<T>> delete<T>(String path, {Options? options}) {
    return dio.delete<T>(path, options: _writeOptions(options));
  }
}
