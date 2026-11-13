import 'package:geolocator/geolocator.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outing_arrivals_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_arrival.dart';

enum ArrivalVerification {
  unverified,
  unavailable,
  permissionDenied,
  outsideRadius,
  arrived,
}

class OutingArrivalService {
  OutingArrivalService(
    this._remote,
    this._socket, {
    Future<bool> Function()? locationEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position> Function()? getPosition,
  }) : _locationEnabled =
           locationEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _getPosition = getPosition ?? _currentPosition;

  final OutingArrivalsRemoteDataSource _remote;
  final OutingChatSocketClient _socket;
  final Future<bool> Function() _locationEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position> Function() _getPosition;

  Stream<String> get arrivalChanges => _socket.arrivalChanges;
  Stream<bool> get connectionChanges => _socket.connectionChanges;
  Future<void> connect() => _socket.ensureConnected();
  Future<OutingArrivalRoster> list(String outingId) => _remote.list(outingId);

  Future<ArrivalVerification> verify(
    String outingId,
    OutingArrivalRoster roster, {
    required bool Function() isActive,
    required bool Function() shouldRequestPermission,
  }) async {
    final venue = roster.venue;
    if (!roster.open || venue == null || !isActive()) {
      return ArrivalVerification.unverified;
    }

    final Position position;
    try {
      if (!await _locationEnabled() || !isActive()) {
        return ArrivalVerification.unavailable;
      }
      var permission = await _checkPermission();
      if (permission == LocationPermission.denied &&
          isActive() &&
          shouldRequestPermission()) {
        permission = await _requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return ArrivalVerification.permissionDenied;
      }
      if (!isActive()) return ArrivalVerification.unverified;
      position = await _getPosition();
    } catch (_) {
      return ArrivalVerification.unavailable;
    }

    if (!isActive()) return ArrivalVerification.unverified;
    if (position.isMocked ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > roster.maxAccuracyMeters ||
        DateTime.now().difference(position.timestamp).abs() >
            const Duration(seconds: 30)) {
      return ArrivalVerification.unavailable;
    }
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      venue.latitude,
      venue.longitude,
    );
    if (!distance.isFinite || distance > roster.radiusMeters) {
      return ArrivalVerification.outsideRadius;
    }
    final arrived = await _remote.record(
      outingId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
    );
    return arrived
        ? ArrivalVerification.arrived
        : ArrivalVerification.unverified;
  }

  static Future<Position> _currentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    ),
  );
}
