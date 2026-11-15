import 'package:maplibre_gl/maplibre_gl.dart' as ml;

// Keep the shared source identifier stable across map consumers.
abstract final class YallaMapClusters {
  static const source = 'yalla-places';

  static Future<void> install(
    ml.MapLibreMapController map,
    Map<String, dynamic> data,
  ) async {
    // Catalog places remain individual category pins at every zoom level.
    await map.addSource(source, ml.GeojsonSourceProperties(data: data));
  }
}
