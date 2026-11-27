import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/theme/app_colors.dart';

typedef PersonalMapMarker = ({
  String key,
  LatLng point,
  IconData icon,
  bool isDefault,
  String? catalogPlaceId,
});

/// Style-local overlay. Its source is separate from the clustered catalog.
class PersonalLocationMapLayer {
  static const source = 'yalla-personal-locations';
  static const dots = 'yalla-personal-location-dots';
  static const _symbols = 'yalla-personal-location-icons';
  static const _empty = {'type': 'FeatureCollection', 'features': []};
  static const _distance = Distance();

  static bool overlaps(LatLng a, LatLng b) => _distance(a, b) <= 8;

  final _images = <IconData, String?>{};
  List<PersonalMapMarker> _shown = const [];

  void reset() {
    _images.clear();
    _shown = const [];
  }

  Future<void> install(
    ml.MapLibreMapController map, {
    required bool dark,
    required bool Function() current,
  }) async {
    await map.addGeoJsonSource(source, _empty);
    if (!current()) return;
    await map.addCircleLayer(
      source,
      dots,
      ml.CircleLayerProperties(
        circleColor:
            '#${AppColors.brand700.toARGB32().toRadixString(16).substring(2)}',
        circleRadius: [
          'case',
          ['get', 'is_default'],
          12,
          10,
        ],
        circleStrokeWidth: [
          'case',
          ['get', 'is_default'],
          3,
          1.5,
        ],
        circleStrokeColor: [
          'case',
          ['get', 'is_default'],
          '#DDD6FE',
          dark ? '#1D1333' : '#FFFFFF',
        ],
      ),
      enableInteraction: false,
    );
    if (!current()) return;
    await map.addSymbolLayer(
      source,
      _symbols,
      const ml.SymbolLayerProperties(
        iconImage: ['get', 'icon'],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: ['has', 'icon'],
      enableInteraction: false,
    );
  }

  Future<void> update(
    ml.MapLibreMapController map,
    List<PersonalMapMarker> markers, {
    required bool Function() current,
  }) async {
    if (listEquals(_shown, markers)) return;
    for (final icon in markers.map((marker) => marker.icon).toSet()) {
      if (_images.containsKey(icon)) continue;
      final id = 'yalla-personal-icon-${icon.codePoint}';
      try {
        final bytes = await _drawIcon(icon);
        if (!current()) return;
        await map.addImage(id, bytes);
        if (!current()) return;
        _images[icon] = id;
      } catch (error) {
        if (!current()) return;
        // The circle remains visible and tappable if a sprite cannot load.
        _images[icon] = null;
        if (kDebugMode) debugPrint('Personal marker icon unavailable');
      }
    }
    if (!current()) return;
    await map.setGeoJsonSource(source, {
      'type': 'FeatureCollection',
      'features': [
        for (final marker in markers)
          {
            'type': 'Feature',
            'id': marker.key,
            'geometry': {
              'type': 'Point',
              'coordinates': [marker.point.longitude, marker.point.latitude],
            },
            'properties': {
              'personal_key': marker.key,
              'is_default': marker.isDefault,
              'icon': ?_images[marker.icon],
            },
          },
      ],
    });
    if (current()) _shown = markers;
  }

  static Future<Uint8List> _drawIcon(IconData icon) async {
    const size = 16;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    )..layout();
    final recorder = ui.PictureRecorder();
    painter.paint(
      Canvas(recorder),
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    painter.dispose();
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(size, size);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Could not encode marker icon');
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
