import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:yalla_5roga/core/monitoring/performance_service.dart';

/// Attaches Firebase Performance [HttpMetric]s to Dio requests.
class PerformanceInterceptor extends Interceptor {
  PerformanceInterceptor();

  final _metrics = <RequestOptions, HttpMetric>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final metric = PerformanceService.instance.newHttpMetric(
      options.uri.toString(),
      _method(options.method),
    );
    if (metric != null) {
      _metrics[options] = metric;
      metric.start();
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final metric = _metrics.remove(response.requestOptions);
    if (metric != null) {
      metric
        ..httpResponseCode = response.statusCode
        ..responseContentType = response.headers.value('content-type')
        ..responsePayloadSize = _payloadSize(response.data);
      metric.stop();
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final metric = _metrics.remove(err.requestOptions);
    if (metric != null) {
      metric.httpResponseCode = err.response?.statusCode;
      metric.stop();
    }
    handler.next(err);
  }

  HttpMethod _method(String method) {
    return switch (method.toUpperCase()) {
      'GET' => HttpMethod.Get,
      'POST' => HttpMethod.Post,
      'PUT' => HttpMethod.Put,
      'DELETE' => HttpMethod.Delete,
      'PATCH' => HttpMethod.Patch,
      'OPTIONS' => HttpMethod.Options,
      'HEAD' => HttpMethod.Head,
      _ => HttpMethod.Get,
    };
  }

  int? _payloadSize(Object? data) {
    if (data == null) return null;
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    return data.toString().length;
  }
}
