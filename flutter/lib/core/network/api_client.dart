import 'package:dio/dio.dart';

class ApiClient {
  const ApiClient(this.dio);

  final Dio dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(String path, {Object? data, Options? options}) {
    return dio.post<T>(path, data: data, options: options);
  }

  Future<Response<T>> put<T>(String path, {Object? data, Options? options}) {
    return dio.put<T>(path, data: data, options: options);
  }

  Future<Response<T>> patch<T>(String path, {Object? data, Options? options}) {
    return dio.patch<T>(path, data: data, options: options);
  }

  Future<Response<T>> delete<T>(String path, {Options? options}) {
    return dio.delete<T>(path, options: options);
  }
}
