import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';

const cairoMapCenter = LatLng(30.0444, 31.2357);

class YallaMapCameraManager {
  ml.MapLibreMapController? native;
  ml.CameraPosition? position;
  bool reduceMotion = false;
  Future<void> focus(
    LatLng point, {
    double zoom = 16,
    double bottom = 0,
    double top = 0,
  }) async {
    final map = native;
    if (map == null) return;
    await map.updateContentInsets(
      EdgeInsets.only(top: top, bottom: bottom),
      false,
    );
    final update = ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(
        target: ml.LatLng(point.latitude, point.longitude),
        zoom: zoom,
        bearing: position?.bearing ?? 0,
        tilt: zoom >= 16 ? 30 : 0,
      ),
    );
    if (reduceMotion) {
      await map.moveCamera(update);
    } else {
      await map.animateCamera(update, duration: AppMotion.emphasis);
    }
  }

  Future<void> resetOrientation() async {
    final map = native;
    final current = position ?? map?.cameraPosition;
    if (map == null || current == null) return;
    final update = ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(target: current.target, zoom: current.zoom),
    );
    if (reduceMotion) {
      await map.moveCamera(update);
    } else {
      await map.animateCamera(update, duration: AppMotion.emphasis);
    }
  }

  Future<void> fit(List<LatLng> points, EdgeInsets padding) async {
    if (native == null || points.isEmpty) return;
    if (points.every((p) => p == points.first)) {
      return focus(points.first, bottom: padding.bottom);
    }
    final lats = points.map((p) => p.latitude).toList()..sort();
    final lngs = points.map((p) => p.longitude).toList()..sort();
    final update = ml.CameraUpdate.newLatLngBounds(
      ml.LatLngBounds(
        southwest: ml.LatLng(lats.first, lngs.first),
        northeast: ml.LatLng(lats.last, lngs.last),
      ),
      left: padding.left,
      right: padding.right,
      top: padding.top,
      bottom: padding.bottom,
    );
    await native!.updateContentInsets(EdgeInsets.zero, false);
    if (reduceMotion) {
      await native!.moveCamera(update);
    } else {
      await native!.animateCamera(update, duration: AppMotion.emphasis);
    }
  }
}
