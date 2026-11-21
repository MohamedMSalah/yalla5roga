import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum MapLocationIssue { disabled, denied, deniedForever, unavailable }

typedef MapLocationFix = ({
  LatLng? point,
  MapLocationIssue? issue,
  double? accuracy,
  DateTime? timestamp,
});

class MapLocation {
  const MapLocation({
    this.timeout = const Duration(seconds: 10),
    this.reuse = const Duration(minutes: 2),
  });
  final Duration timeout, reuse;
  static MapLocationFix? _last;
  static Future<Position>? _acquiring;
  static Future<LocationPermission>? _prompt;
  static bool _asked = false;
  static const _platformTimeout = Duration(seconds: 2);

  static Future<LocationPermission> requestPermissionOnce() async {
    if (_prompt case final prompt?) return prompt;
    if (_asked) return Geolocator.checkPermission();
    _asked = true;
    return _prompt = Geolocator.requestPermission().whenComplete(
      () => _prompt = null,
    );
  }

  static Future<T> _timed<T>(String stage, Future<T> Function() task) async {
    if (!kDebugMode) return task();
    final timer = Stopwatch()..start();
    try {
      return await task();
    } finally {
      debugPrint('Map location $stage ${timer.elapsedMilliseconds} ms');
    }
  }

  static MapLocationFix? _fix(Position? p) {
    if (p == null ||
        !p.latitude.isFinite ||
        !p.longitude.isFinite ||
        p.latitude.abs() > 90 ||
        p.longitude.abs() > 180 ||
        p.timestamp.isAfter(DateTime.now())) {
      return null;
    }
    return (
      point: LatLng(p.latitude, p.longitude),
      issue: null,
      accuracy: p.accuracy,
      timestamp: p.timestamp,
    );
  }

  Future<bool> get permitted async {
    final p = await Geolocator.checkPermission().timeout(_platformTimeout);
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<MapLocationFix?> previous() async {
    try {
      final permission = await Geolocator.checkPermission().timeout(
        _platformTimeout,
      );
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return _last ??
          _fix(
            await _timed(
              'previous',
              () => Geolocator.getLastKnownPosition().timeout(
                const Duration(seconds: 2),
              ),
            ),
          );
    } catch (_) {
      return null;
    }
  }

  Future<({LatLng? point, MapLocationIssue? issue})> locate({
    required bool requestPermission,
  }) async {
    final fix = await locateFix(requestPermission: requestPermission);
    return (point: fix.point, issue: fix.issue);
  }

  Future<MapLocationFix> locateFix({required bool requestPermission}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled().timeout(
        _platformTimeout,
      )) {
        return (
          point: null,
          accuracy: null,
          timestamp: null,
          issue: MapLocationIssue.disabled,
        );
      }
      var permission = await _timed(
        'permission',
        () => Geolocator.checkPermission().timeout(_platformTimeout),
      );
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await requestPermissionOnce();
      }
      if (permission == LocationPermission.deniedForever) {
        return (
          point: null,
          accuracy: null,
          timestamp: null,
          issue: MapLocationIssue.deniedForever,
        );
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return (
          point: null,
          accuracy: null,
          timestamp: null,
          issue: MapLocationIssue.denied,
        );
      }
      final last = _last;
      if (last != null && DateTime.now().difference(last.timestamp!) < reuse) {
        return last;
      }
      final position = await (_acquiring ??= _timed(
        'fresh',
        () => Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: timeout,
          ),
        ),
      ).whenComplete(() => _acquiring = null));
      final fix = _fix(position);
      if (fix == null) throw StateError('Invalid location');
      _last = fix;
      return fix;
    } catch (_) {
      return (
        point: null,
        accuracy: null,
        timestamp: null,
        issue: MapLocationIssue.unavailable,
      );
    }
  }
}
