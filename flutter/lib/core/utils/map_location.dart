import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum MapLocationIssue { disabled, denied, deniedForever, unavailable }

class MapLocation {
  const MapLocation();

  Future<({LatLng? point, MapLocationIssue? issue})> locate({
    required bool requestPermission,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (point: null, issue: MapLocationIssue.disabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return (point: null, issue: MapLocationIssue.deniedForever);
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return (point: null, issue: MapLocationIssue.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (
        point: LatLng(position.latitude, position.longitude),
        issue: null,
      );
    } catch (_) {
      return (point: null, issue: MapLocationIssue.unavailable);
    }
  }
}
