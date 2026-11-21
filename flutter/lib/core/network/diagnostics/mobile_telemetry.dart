import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

class MobileTelemetry {
  MobileTelemetry(this._dio, this._uid);

  static final sample =
      (double.tryParse(
                const String.fromEnvironment(
                  'API_TELEMETRY_SAMPLE',
                  defaultValue: '0',
                ),
              ) ??
              0)
          .clamp(0, 0.1);
  static const ignoredKey = 'skip_request_telemetry';
  final Dio _dio;
  final String? Function() _uid;
  final _random = Random();
  final _buffer = <Map<String, Object>>[];
  String? _owner;
  bool _sending = false;

  void record({
    required String endpoint,
    required String method,
    required int status,
    required double clientMs,
    double? serverMs,
    String? cache,
  }) {
    if (sample <= 0 || !endpoint.startsWith('/api/') || clientMs > 120000) {
      return;
    }
    final uid = _uid();
    if (uid != _owner) {
      _buffer.clear();
      _owner = uid;
    }
    if (uid == null || _random.nextDouble() >= sample || _buffer.length >= 12) {
      return;
    }
    _buffer.add({
      'endpoint': endpoint,
      'method': method,
      'status': status,
      'clientMs': clientMs,
      if (serverMs != null && serverMs <= 120000) 'serverMs': serverMs,
      if (cache == 'hit' || cache == 'miss' || cache == 'stale')
        'cache': cache!,
    });
    if (_buffer.length == 12 && !_sending) {
      final batch = List.of(_buffer);
      _buffer.clear();
      unawaited(_send(uid, batch));
    }
  }

  Future<void> _send(String uid, List<Map<String, Object>> batch) async {
    _sending = true;
    try {
      await _dio.post<void>(
        '/monitoring/mobile',
        data: batch,
        options: Options(extra: {ignoredKey: true, expectedUserIdKey: uid}),
      );
    } catch (_) {
      // Drop failed batches quietly. Telemetry never triggers retries.
    } finally {
      _sending = false;
    }
  }
}
