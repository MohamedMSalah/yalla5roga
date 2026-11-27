import 'package:latlong2/latlong.dart';

bool isRouteMapPoint(LatLng point) =>
    point.latitude.isFinite &&
    point.longitude.isFinite &&
    point.latitude.abs() <= 90 &&
    point.longitude.abs() <= 180;

bool isRouteMapLine(List<LatLng> points) =>
    points.length >= 2 &&
    points.every(isRouteMapPoint) &&
    points.any((point) => point != points.first);
