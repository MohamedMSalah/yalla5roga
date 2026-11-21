import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';

abstract final class YallaMapClusters {
  static const source = 'yalla-places';
  static const pins = 'yalla-cluster-pins';
  static const count = 'yalla-cluster-count';

  static String assetId(bool dark) => dark ? 'cluster_dark' : 'cluster_light';

  // The 192px sprite's foreground face is centered at (96, 96).
  // Scale the glyphs with the sprite to keep the em offset centered on it.
  static const _countOffset = 1.7;
  static List<Object> _size(double small, double medium, double large) => [
    'step',
    ['get', 'point_count'],
    small,
    20,
    medium,
    100,
    large,
  ];

  static Future<void> install(
    ml.MapLibreMapController map, {
    required bool dark,
  }) async {
    const filter = ['has', 'point_count'];
    await map.addSource(
      source,
      ml.GeojsonSourceProperties(
        data: const {'type': 'FeatureCollection', 'features': []},
        cluster: true,
        clusterRadius: 48,
        clusterMaxZoom: 13,
      ),
    );
    await map.addSymbolLayer(
      source,
      pins,
      ml.SymbolLayerProperties(
        iconImage: 'yalla-${assetId(dark)}',
        iconSize: _size(.215, .25, .29),
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
      ),
      filter: filter,
    );
    await map.addSymbolLayer(
      source,
      count,
      ml.SymbolLayerProperties(
        textField: [
          'to-string',
          ['get', 'point_count'],
        ],
        // Use the existing glyph stack so previously downloaded map packs
        // can render the count. A hairline halo gives the digits more weight.
        textFont: [YallaMapStyle.font],
        textColor: '#FFFFFF',
        textHaloColor: '#FFFFFF',
        textHaloWidth: .3,
        textSize: _size(12, 14, 16.2),
        textAnchor: 'center',
        textOffset: [0, -_countOffset],
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: filter,
      enableInteraction: false,
    );
  }
}
