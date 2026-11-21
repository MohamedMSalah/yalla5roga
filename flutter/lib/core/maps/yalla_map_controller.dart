import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/maps/yalla_map_camera_manager.dart';

/// Route-owned camera state survives style changes and map-page navigation.
class YallaMapController extends ChangeNotifier {
  final camera = YallaMapCameraManager();
  final attributionInset = ValueNotifier<double>(0);
  VoidCallback? _pending;
  bool ready = false;
  bool failed = false;
  bool disposed = false;
  double selectionBottom = 0;
  double selectionTop = 0;
  LatLng selectionPoint = cairoMapCenter;
  void attach() {
    if (disposed) return;
    ready = true;
    final action = _pending;
    _pending = null;
    action?.call();
  }

  void detach() {
    ready = false;
    camera.native = null;
  }

  void _whenReady(VoidCallback action) {
    if (disposed) return;
    if (ready) {
      action();
    } else {
      _pending = action;
    }
  }

  void _run(Future<void> Function() action) => _whenReady(
    () => unawaited(action().catchError((Object _) => reportFailure(true))),
  );
  void focus(LatLng point, {double zoom = 16}) =>
      _run(() => camera.focus(point, zoom: zoom));
  void resetOrientation() => _run(camera.resetOrientation);
  void focusSelection(LatLng point, {double zoom = 16}) => _run(
    () => camera.focus(
      point,
      zoom: zoom,
      bottom: selectionBottom,
      top: selectionTop,
    ),
  );
  void fit(List<LatLng> points, {required EdgeInsets padding}) =>
      _run(() => camera.fit(points, padding));
  void reportFailure(bool value) {
    if (disposed || value == failed) return;
    failed = value;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    _pending = null;
    detach();
    attributionInset.dispose();
    super.dispose();
  }
}
