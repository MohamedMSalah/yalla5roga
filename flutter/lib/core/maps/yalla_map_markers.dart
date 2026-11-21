import 'dart:convert';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:yalla_5roga/core/maps/yalla_map_clusters.dart';
import 'package:yalla_5roga/core/maps/yalla_map_place_selection.dart';
import 'package:yalla_5roga/core/maps/yalla_map_style.dart';
import 'package:yalla_5roga/core/maps/yalla_pin_categories.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

class YallaMapMarkers {
  static const pins = 'yalla-pins',
      privateSource = 'yalla-private-places',
      privatePins = 'yalla-private-pins',
      selectedSource = 'yalla-selected',
      selectedPins = 'yalla-selected-pins',
      _glow = 'yalla-selected-glow',
      customSource = 'yalla-custom-selection',
      customPoints = 'yalla-custom-points',
      customOrder = 'yalla-custom-order';
  static const assetPath = 'assets/map/pins';
  static String assetId(String categoryId) =>
      yallaPinCategories.contains(categoryId) ? categoryId : 'fallback';

  static const _selectionGrowth = .4;
  static const _privateSize = .30;
  static const _previousPinSize = .27;
  static const _zoomSizes = [(8, .29), (10, .35), (12, _previousPinSize * 1.5)];
  static const _empty = {'type': 'FeatureCollection', 'features': []};

  final _images = <String>{};
  String? _lastData, _lastPrivate, _lastCustom, _selectionKey;
  Map<String, Map<String, dynamic>> _selected = {}, _departing = {};
  Map<String, double> _starts = {};
  String _ink = '', _halo = '';

  void reset() {
    _images.clear();
    _lastData = _lastPrivate = _lastCustom = _selectionKey = null;
    _selected.clear();
    _departing.clear();
    _starts.clear();
  }

  static Map<String, dynamic> collection(
    Iterable<Place> places, {
    required String language,
    bool includeUnavailable = false,
  }) => {
    'type': 'FeatureCollection',
    'features': [
      for (final place in places)
        if (place.id.isNotEmpty &&
            (includeUnavailable || place.status == 'active') &&
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
              'name': place.id.startsWith('private:')
                  ? '◆ ${place.displayName(language)}'
                  : place.displayName(language),
              'category': place.categoryId,
              'icon':
                  place.id.startsWith('private:') && place.categoryId.isEmpty
                  ? 'yalla-private'
                  : 'yalla-${assetId(place.categoryId)}',
              'private_place': place.id.startsWith('private:'),
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
    Iterable<Place> places, {
    required bool dark,
  }) async {
    for (final id in {
      'fallback',
      'private',
      'selection_check',
      'selection_glow',
      YallaMapClusters.assetId(dark),
      'landmark_school',
      'landmark_culture',
      ...places.map((place) => assetId(place.categoryId)),
    }) {
      if (_images.contains(id)) continue;
      final directory = id.startsWith('landmark_')
          ? 'assets/map/landmarks'
          : assetPath;
      ByteData bytes;
      try {
        bytes = await rootBundle.load('$directory/$id.png');
      } on FlutterError {
        if (!yallaPinCategories.contains(id)) rethrow;
        bytes = await rootBundle.load('$assetPath/fallback.png');
      }
      try {
        await map.addImage('yalla-$id', _bytes(bytes));
      } on PlatformException catch (error) {
        if (error.code != 'INVALID_IMAGE' || !yallaPinCategories.contains(id)) {
          rethrow;
        }
        final fallback = await rootBundle.load('$assetPath/fallback.png');
        await map.addImage('yalla-$id', _bytes(fallback));
      }
      _images.add(id);
    }
  }

  static Uint8List _bytes(ByteData bytes) =>
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);

  static List<Object> _zoomSize(Object Function(double size) value) => [
    'interpolate',
    ['linear'],
    ['zoom'],
    for (final (zoom, size) in _zoomSizes) ...[zoom, value(size)],
  ];

  static List<Object> _baseSize(double size) => [
    'case',
    [
      '==',
      ['get', 'icon'],
      'yalla-private',
    ],
    _privateSize,
    ['get', 'private_place'],
    size * (_privateSize / _previousPinSize),
    size,
  ];

  ml.SymbolLayerProperties _catalogPinProperties({
    required bool selected,
    required Object size,
  }) => ml.SymbolLayerProperties(
    iconImage: ['get', 'icon'],
    iconSize: size,
    iconAnchor: 'bottom',
    iconPadding: 3,
    iconAllowOverlap: selected,
    iconIgnorePlacement: selected,
    textField: ['get', 'name'],
    textFont: [YallaMapStyle.font],
    textSize: 12,
    textAnchor: 'top',
    textOffset: [0, .4],
    textMaxWidth: selected ? 12 : 10,
    textColor: _ink,
    textHaloColor: _halo,
    textHaloWidth: 1.5,
    textOptional: true,
    textAllowOverlap: selected,
    textIgnorePlacement: selected,
  );

  ml.SymbolLayerProperties _glowProperties(Object size, Object opacity) =>
      ml.SymbolLayerProperties(
        iconImage: 'yalla-selection_glow',
        iconSize: size,
        iconOpacity: opacity,
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      );

  static const _unclustered = [
    '!',
    ['has', 'point_count'],
  ];

  Future<void> install(
    ml.MapLibreMapController map, {
    required bool dark,
    bool showChecks = false,
  }) async {
    _ink = dark ? '#F5F3FF' : '#34264A';
    _halo = dark ? '#0D1020' : '#FFFFFF';
    await map.addSymbolLayer(
      YallaMapClusters.source,
      pins,
      _catalogPinProperties(selected: false, size: _zoomSize((size) => size)),
      filter: _unclustered,
    );
    await map.addGeoJsonSource(privateSource, _empty);
    await map.addSymbolLayer(
      privateSource,
      privatePins,
      _catalogPinProperties(selected: false, size: _zoomSize(_baseSize)),
    );
    // Explicitly chosen geographic locations are selection annotations, never
    // generated catalog places/category pins.
    await map.addGeoJsonSource(customSource, _empty);
    if (showChecks) {
      await map.addCircleLayer(
        customSource,
        'yalla-custom-halo',
        const ml.CircleLayerProperties(
          circleRadius: 36,
          circleColor: '#8739E3',
          circleOpacity: .30,
        ),
        enableInteraction: false,
      );
    }
    await map.addSymbolLayer(
      customSource,
      customPoints,
      ml.SymbolLayerProperties(
        iconImage: showChecks ? 'yalla-selection_check' : 'yalla-private',
        iconSize: showChecks ? .5 : .32,
        iconAnchor: showChecks ? 'center' : 'bottom',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
    await map.addSymbolLayer(
      customSource,
      customOrder,
      ml.SymbolLayerProperties(
        textField: [
          'case',
          ['has', 'selection_order'],
          [
            'concat',
            ['get', 'selection_order'],
            ' · ',
            ['get', 'name'],
          ],
          ['get', 'name'],
        ],
        textFont: [YallaMapStyle.font],
        textSize: 11,
        textAnchor: 'top',
        textMaxWidth: 12,
        textOffset: showChecks ? [0, 1.5] : [0, .25],
        textColor: _ink,
        textHaloColor: _halo,
        textHaloWidth: 1.5,
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      enableInteraction: false,
    );
    await map.addGeoJsonSource(selectedSource, _empty);
    final selectedSize = _selectedSize(1);
    await map.addSymbolLayer(
      selectedSource,
      _glow,
      _glowProperties(selectedSize, 1),
      enableInteraction: false,
    );
    await map.addSymbolLayer(
      selectedSource,
      selectedPins,
      _catalogPinProperties(selected: true, size: selectedSize),
    );
  }

  Future<void> update(
    ml.MapLibreMapController map, {
    required String dataKey,
    required String privateKey,
    required Map<String, dynamic> privateData,
    required Map<String, dynamic> data,
    required Map<String, dynamic> custom,
    required String customKey,
  }) async {
    if (_lastData != dataKey) {
      await map.setGeoJsonSource(YallaMapClusters.source, data);
      _lastData = dataKey;
    }
    if (_lastPrivate != privateKey) {
      await map.setGeoJsonSource(privateSource, privateData);
      _lastPrivate = privateKey;
    }
    if (_lastCustom != customKey) {
      await map.setGeoJsonSource(customSource, custom);
      _lastCustom = customKey;
    }
  }

  Future<bool> updateSelection(
    ml.MapLibreMapController map,
    Map<String, dynamic> selection, {
    required bool animate,
    required double progress,
  }) async {
    final key = jsonEncode(selection);
    if (_selectionKey == key) {
      if (!animate && _starts.isNotEmpty) await selectionFrame(map, 1);
      return false;
    }

    final desired = {
      for (final Map<String, dynamic> feature in selection['features'] as List)
        feature['id'] as String: feature,
    };
    final changed =
        desired.length != _selected.length ||
        !desired.keys.every(_selected.containsKey);
    if (changed) {
      final previous = {..._departing, ..._selected};
      final nextStarts = <String, double>{};
      final departing = <String, Map<String, dynamic>>{};
      if (animate && _selectionKey != null) {
        for (final id in {...previous.keys, ...desired.keys}) {
          final current = _progressFor(id, progress);
          final target = desired.containsKey(id) ? 1.0 : 0.0;
          if (current != target) {
            nextStarts[id] = current;
            if (target == 0) departing[id] = previous[id]!;
          }
        }
      }
      _starts = nextStarts;
      _departing = departing;
    }
    if (!animate) {
      _departing.clear();
      _starts.clear();
    }
    _selected = desired;
    _selectionKey = key;
    final start = changed && _starts.isNotEmpty;
    if (changed || !animate) {
      await selectionFrame(map, start ? 0 : 1);
    }
    await _showSelection(map);
    return start;
  }

  Future<void> _showSelection(ml.MapLibreMapController map) async {
    final features = {..._departing, ..._selected};
    await map.setGeoJsonSource(selectedSource, {
      'type': 'FeatureCollection',
      'features': features.values.toList(growable: false),
    });
    final exclude = [
      '!',
      [
        'in',
        ['get', 'place_id'],
        ['literal', features.keys.toList()],
      ],
    ];
    await map.setFilter(privatePins, exclude);
    await map.setFilter(pins, ['all', _unclustered, exclude]);
  }

  double _progressFor(String id, double progress) =>
      lerpDouble(_starts[id] ?? _target(id), _target(id), progress)!;

  double _target(String id) => _selected.containsKey(id) ? 1 : 0;

  Object _match(double progress, Object Function(double) value) {
    if (_starts.isEmpty) return value(1);
    return [
      'match',
      ['get', 'place_id'],
      for (final id in _starts.keys) ...[id, value(_progressFor(id, progress))],
      value(1),
    ];
  }

  Object _selectedSize(double progress) => _zoomSize(
    (size) => [
      '*',
      _baseSize(size),
      _match(progress, (value) => 1 + _selectionGrowth * value),
    ],
  );

  Future<void> selectionFrame(
    ml.MapLibreMapController map,
    double progress,
  ) async {
    final finished = progress >= 1;
    final hadDeparting = _departing.isNotEmpty;
    if (_starts.isEmpty && !finished) return;
    final size = _selectedSize(progress);
    // setLayerProperties replaces omitted properties with their SDK defaults.
    // Send the full style on every frame so the category artwork stays visible.
    await map.setLayerProperties(
      selectedPins,
      _catalogPinProperties(selected: true, size: size),
    );
    await map.setLayerProperties(
      _glow,
      _glowProperties(size, _match(progress, (value) => value)),
    );
    if (finished) {
      _starts.clear();
      _departing.clear();
      if (hadDeparting) await _showSelection(map);
    }
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
      for (final p in [...selection.selected, ...places])
        if (p.id.isNotEmpty &&
            (p.id == selection.focusedId || chosen.any(p.matchesSelection)))
          p.id: p,
    }.values.toList();
  }
}
