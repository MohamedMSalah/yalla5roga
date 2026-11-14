import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';

abstract final class YallaMapClusters {
  static const source = 'yalla-places';
  static const circles = 'yalla-clusters';
  static const counts = 'yalla-cluster-counts';
  static const radius = 52.0;
  static const maxZoom = 16.0;
  static Future<void> install(
    ml.MapLibreMapController map,
    Map<String, dynamic> data, {
    required bool arabic,
  }) async {
    await map.addSource(
      source,
      ml.GeojsonSourceProperties(
        data: data,
        cluster: true,
        clusterRadius: radius,
        clusterMaxZoom: maxZoom,
      ),
    );
    await map.addCircleLayer(
      source,
      circles,
      const ml.CircleLayerProperties(
        circleColor: '#6854B8',
        circleRadius: [
          'step',
          ['get', 'point_count'],
          23,
          50,
          27,
          200,
          31,
        ],
        circleStrokeWidth: 2,
        circleStrokeColor: '#FFFFFF',
        circleOpacity: .96,
      ),
      filter: ['has', 'point_count'],
    );
    dynamic count = [
      'to-string',
      ['get', 'point_count_abbreviated'],
    ];
    // Cluster counts follow the same Arabic-Indic policy as L10n.n.
    if (arabic) {
      // Style expressions have no replace operator; number-format supports locale.
      count = [
        'number-format',
        ['get', 'point_count'],
        {'locale': 'ar-EG', 'max-fraction-digits': 0},
      ];
    }
    await map.addSymbolLayer(
      source,
      counts,
      ml.SymbolLayerProperties(
        textField: count,
        textFont: const [YallaMapStyle.font],
        textSize: 13,
        textColor: '#FFFFFF',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
      enableInteraction: false,
    );
  }
}
