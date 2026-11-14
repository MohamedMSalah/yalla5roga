import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/maps/yalla_map_clusters.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';
import 'package:yalla_5roga/core/widgets/place_catalog_filters.dart';
import 'package:yalla_5roga/features/discover/domain/entities/place_catalog.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

class YallaMapMarkers {
  static const pins = 'yalla-pins',
      selectedSource = 'yalla-selected',
      selectedPins = 'yalla-selected-pins',
      ring = 'yalla-selected-ring',
      customSource = 'yalla-custom-selection',
      customPoints = 'yalla-custom-points';
  final _images = <String>{};
  String? _lastData, _lastSelected, _lastCustom;
  void reset() {
    _images.clear();
    _lastData = null;
    _lastSelected = null;
    _lastCustom = null;
  }

  static Map<String, dynamic> collection(
    Iterable<Place> places,
    List<CatalogDefinition> categories,
  ) => {
    'type': 'FeatureCollection',
    'features': [
      for (final place in places)
        if (place.id.isNotEmpty &&
            place.status == 'active' &&
            validPoint(place))
          {
            'type': 'Feature',
            'id': place.id,
            'geometry': {
              'type': 'Point',
              'coordinates': [place.longitude, place.latitude],
            },
            'properties': {
              'place_id': place.id,
              'name': place.name,
              'category': place.categoryId,
              'vibes': place.vibeIds,
              'image_url': place.imageUrl,
              'status': place.status,
              'icon': 'yalla-${place.categoryId}',
              'sort': 0,
            },
          },
    ],
  };
  static bool validPoint(Place p) =>
      p.hasCoordinates &&
      p.latitude!.isFinite &&
      p.longitude!.isFinite &&
      p.latitude!.abs() <= 85.051129 &&
      p.longitude!.abs() <= 180;

  Future<void> images(
    ml.MapLibreMapController map,
    Iterable<Place> places,
    List<CatalogDefinition> definitions,
  ) async {
    for (final category in places.map((p) => p.categoryId).toSet()) {
      final definition = definitions.where((d) => d.id == category).firstOrNull;
      final signature = '$category:${definition?.icon}:${definition?.group}';
      if (_images.contains(signature)) continue;
      final icon = catalogIcon(definition?.icon ?? 'place', true);
      final color = switch (definition?.group) {
        'food_drinks' => const Color(0xFFB45326),
        'outdoor' => const Color(0xFF28734D),
        'culture' => const Color(0xFF346B8A),
        'shopping' => const Color(0xFFA23567),
        _ => const Color(0xFF6854B8),
      };
      // One compact, 2x style image per category, reused by native symbol layers.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(2);
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 3, 32, 34),
            const Radius.circular(12),
          ),
        );
      canvas.drawShadow(shape, const Color(0x66000000), 2, true);
      canvas.drawPath(shape, Paint()..color = Colors.white);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(6, 5, 28, 30),
          const Radius.circular(10),
        ),
        Paint()..color = color,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 19,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset((40 - painter.width) / 2, (40 - painter.height) / 2),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(80, 80);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await map.addImage('yalla-$category', bytes!.buffer.asUint8List());
      painter.dispose();
      image.dispose();
      picture.dispose();
      _images.add(signature);
    }
  }

  Future<void> install(ml.MapLibreMapController map) async {
    await map.addSymbolLayer(
      YallaMapClusters.source,
      pins,
      const ml.SymbolLayerProperties(
        iconImage: ['get', 'icon'],
        iconSize: .5,
        iconPadding: 6,
        iconAllowOverlap: false,
        symbolSortKey: ['get', 'sort'],
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );
    await map.addGeoJsonSource(selectedSource, {
      'type': 'FeatureCollection',
      'features': [],
    });
    await map.addCircleLayer(
      selectedSource,
      ring,
      const ml.CircleLayerProperties(
        circleRadius: 25,
        circleColor: '#FFFFFF',
        circleOpacity: .88,
        circleStrokeColor: '#7962D1',
        circleStrokeWidth: 3,
      ),
      enableInteraction: false,
    );
    await map.addSymbolLayer(
      selectedSource,
      selectedPins,
      const ml.SymbolLayerProperties(
        iconImage: ['get', 'icon'],
        iconSize: .67,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        textField: [
          'coalesce',
          ['get', 'selection_order'],
          '',
        ],
        textFont: [YallaMapStyle.font],
        textSize: 12,
        textOffset: [1.4, -1.4],
        textColor: '#47357E',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 2,
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );
    // Explicitly chosen geographic locations are selection annotations, never
    // generated catalog places/category pins.
    await map.addGeoJsonSource(customSource, {
      'type': 'FeatureCollection',
      'features': [],
    });
    await map.addCircleLayer(
      customSource,
      customPoints,
      const ml.CircleLayerProperties(
        circleRadius: 15,
        circleColor: '#FFFFFF',
        circleStrokeColor: '#7962D1',
        circleStrokeWidth: 3,
      ),
    );
    await map.addSymbolLayer(
      customSource,
      'yalla-custom-order',
      const ml.SymbolLayerProperties(
        textField: ['get', 'selection_order'],
        textFont: [YallaMapStyle.font],
        textSize: 12,
        textColor: '#47357E',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      enableInteraction: false,
    );
  }

  Future<void> update(
    ml.MapLibreMapController map, {
    required String dataKey,
    required Map<String, dynamic> data,
    required Map<String, dynamic> selected,
    required String selectedKey,
    required Map<String, dynamic> custom,
    required String customKey,
  }) async {
    if (_lastData != dataKey) {
      await map.setGeoJsonSource(YallaMapClusters.source, data);
      _lastData = dataKey;
    }
    if (_lastCustom != customKey) {
      await map.setGeoJsonSource(customSource, custom);
      _lastCustom = customKey;
    }
    if (_lastSelected != selectedKey) {
      await map.setGeoJsonSource(selectedSource, selected);
      _lastSelected = selectedKey;
      // Selected records live above clusters and cannot be swallowed by clustering.
      final ids = (selected['features'] as List)
          .map((f) => f['properties']['place_id'])
          .toList();
      await map.setFilter(pins, [
        'all',
        [
          '!',
          ['has', 'point_count'],
        ],
        [
          '!',
          [
            'in',
            ['get', 'place_id'],
            ['literal', ids],
          ],
        ],
      ]);
    }
  }

  Future<void> selectionFrame(ml.MapLibreMapController map, double t) async {
    await map.setLayerProperties(
      selectedPins,
      ml.SymbolLayerProperties(iconSize: .5 + .17 * t),
    );
    await map.setLayerProperties(
      ring,
      ml.CircleLayerProperties(
        circleRadius: 20 + 5 * t,
        circleStrokeWidth: 1 + 2 * t,
      ),
    );
  }

  static List<Place> highlighted(
    List<Place> places,
    YallaMapPlaceSelection selection,
  ) {
    final chosen = switch (selection.mode) {
      YallaMapSelectionMode.browse => <Place>[],
      YallaMapSelectionMode.single => selection.selected.take(1).toList(),
      YallaMapSelectionMode.multiple => selection.selected,
    };
    return {
      for (final p in [...places, ...selection.selected])
        if (p.id.isNotEmpty &&
            (p.id == selection.focusedId || chosen.any(p.matchesSelection)))
          p.id: p,
    }.values.toList();
  }
}
