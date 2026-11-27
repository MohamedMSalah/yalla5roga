import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'route_geometry.dart';

typedef PersonalRouteOverlay = ({
  List<LatLng> selected,
  List<List<LatLng>> alternatives,
  LatLng? origin,
  LatLng destination,
});

class PersonalRouteMapLayer {
  static const _selected = 'yalla-route-selected';
  static const _alternatives = 'yalla-route-alternatives';
  static const _origin = 'yalla-route-origin';
  static const _destination = 'yalla-route-destination';
  static const _empty = {'type': 'FeatureCollection', 'features': []};

  bool _installed = false;
  PersonalRouteOverlay? _shown;

  void reset() {
    _installed = false;
    _shown = null;
  }

  Future<void> render(
    ml.MapLibreMapController map,
    PersonalRouteOverlay? overlay, {
    required bool dark,
    required bool Function() current,
  }) async {
    if (_shown == overlay) return;
    if (!_installed) {
      for (final id in [_alternatives, _selected, _origin, _destination]) {
        await map.addGeoJsonSource(id, _empty);
        if (!current()) return;
      }
      for (final (id, color, width) in [
        (_alternatives, dark ? '#8B90AD' : '#666C8B', 4.0),
        (_selected, dark ? '#C4B5FD' : '#633BC6', 6.0),
      ]) {
        await map.addLineLayer(
          id,
          '$id-line',
          ml.LineLayerProperties(
            lineColor: color,
            lineWidth: width,
            lineJoin: 'round',
            lineCap: 'round',
          ),
          enableInteraction: false,
        );
        if (!current()) return;
      }
      for (final (id, color) in [
        (_origin, dark ? '#93C5FD' : '#1746A2'),
        (_destination, dark ? '#C4B5FD' : '#633BC6'),
      ]) {
        await map.addCircleLayer(
          id,
          '$id-dot',
          ml.CircleLayerProperties(
            circleRadius: 7,
            circleColor: color,
            circleStrokeWidth: 2,
            circleStrokeColor: dark ? '#1D1333' : '#FFFFFF',
          ),
          enableInteraction: false,
        );
        if (!current()) return;
      }
      _installed = true;
    }
    for (final (id, features) in [
      (_selected, _lines(overlay == null ? const [] : [overlay.selected])),
      (_alternatives, _lines(overlay?.alternatives ?? const [])),
      (_origin, _marker(overlay?.origin)),
      (_destination, _marker(overlay?.destination)),
    ]) {
      await map.setGeoJsonSource(id, {
        'type': 'FeatureCollection',
        'features': features,
      });
      if (!current()) return;
    }
    _shown = overlay;
  }

  static List<double> _position(LatLng point) => [
    point.longitude,
    point.latitude,
  ];

  static List<Map<String, Object>> _lines(List<List<LatLng>> lines) => [
    for (final line in lines)
      if (isRouteMapLine(line))
        _feature('LineString', line.map(_position).toList(growable: false)),
  ];

  static List<Map<String, Object>> _marker(LatLng? point) => [
    if (point != null && isRouteMapPoint(point))
      _feature('Point', _position(point)),
  ];

  static Map<String, Object> _feature(String type, Object coordinates) => {
    'type': 'Feature',
    'geometry': {'type': type, 'coordinates': coordinates},
    'properties': <String, Object>{},
  };
}
