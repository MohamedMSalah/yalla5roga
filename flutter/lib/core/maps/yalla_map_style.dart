import 'dart:convert';

/// OpenMapTiles schema only; no provider-specific behavior in the map UI.
abstract final class YallaMapStyle {
  static const tileJsonUrl = String.fromEnvironment(
    'MAP_VECTOR_TILEJSON_URL',
    defaultValue: 'https://tiles.openfreemap.org/planet/latest',
  );
  static const glyphsUrl = String.fromEnvironment(
    'MAP_GLYPHS_URL',
    defaultValue: 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
  );
  static const attribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: 'OpenFreeMap · © OpenMapTiles · © OpenStreetMap contributors · Overture Maps Foundation',
  );
  static const attributionUrl = String.fromEnvironment(
    'MAP_ATTRIBUTION_URL',
    defaultValue: 'https://openfreemap.org/quick_start/',
  );
  static const lightStyleUrl = String.fromEnvironment('MAP_LIGHT_STYLE_URL');
  static const darkStyleUrl = String.fromEnvironment('MAP_DARK_STYLE_URL');
  static const offlineAllowed = bool.fromEnvironment(
    'MAP_OFFLINE_ALLOWED',
    defaultValue: true,
  );
  static const font = 'Noto Sans Regular';

  static String resolve({required bool dark, required String language}) {
    final override = dark ? darkStyleUrl : lightStyleUrl;
    return override.isNotEmpty
        ? override.replaceAll('{language}', language == 'ar' ? 'ar' : 'en')
        : jsonEncode(build(dark: dark, language: language));
  }

  static Map<String, dynamic> build({
    required bool dark,
    required String language,
  }) {
    final land = dark ? '#202628' : '#F7F8F4';
    final water = dark ? '#285569' : '#A9DCEB';
    final park = dark ? '#304B3E' : '#CFE8CF';
    final grass = dark ? '#2B4034' : '#DDEDD6';
    final building = dark ? '#383F40' : '#E8E9E6';
    final outline = dark ? '#495151' : '#D5D8D4';
    final ink = dark ? '#D6DEDA' : '#414D4C';
    final halo = dark ? '#202628' : '#F7F8F4';
    dynamic name = '';
    for (final key in [
      'name:${language == 'ar' ? 'ar' : 'en'}',
      'name_${language == 'ar' ? 'ar' : 'en'}',
      'name',
      'name:latin',
    ].reversed) {
      name = [
        'case',
        [
          'all',
          ['has', key],
          [
            '!=',
            ['get', key],
            '',
          ],
        ],
        ['get', key],
        name,
      ];
    }
    List<dynamic> classes(List<String> values) => [
      'in',
      ['get', 'class'],
      ['literal', values],
    ];
    List<dynamic> width(double a, double b, double c) => [
      'interpolate',
      ['linear'],
      ['zoom'],
      7,
      a,
      13,
      b,
      18,
      c,
    ];
    Map<String, dynamic> fill(
      String id,
      String source,
      String color, {
      dynamic filter,
      double? minzoom,
    }) => {
      'id': id,
      'type': 'fill',
      'source': 'basemap',
      'source-layer': source,
      'filter': ?filter,
      'minzoom': ?minzoom,
      'paint': {'fill-color': color},
    };
    Map<String, dynamic> line(
      String id,
      String source,
      String color,
      dynamic w, {
      dynamic filter,
      double minzoom = 0,
    }) => {
      'id': id,
      'type': 'line',
      'source': 'basemap',
      'source-layer': source,
      'minzoom': minzoom,
      'filter': ?filter,
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {'line-color': color, 'line-width': w},
    };
    Map<String, dynamic> label(
      String id,
      String source,
      double size, {
      dynamic filter,
      double minzoom = 0,
      bool road = false,
    }) => {
      'id': id,
      'type': 'symbol',
      'source': 'basemap',
      'source-layer': source,
      'minzoom': minzoom,
      'filter': ?filter,
      'layout': {
        'text-field': name,
        'text-font': [font],
        'text-size': size,
        'text-padding': road ? 12 : 8,
        'text-max-width': 8,
        'text-allow-overlap': false,
        if (road) ...{'symbol-placement': 'line', 'symbol-spacing': 420},
      },
      'paint': {
        'text-color': ink,
        'text-halo-color': halo,
        'text-halo-width': 1.4,
      },
    };
    final major = classes(['motorway', 'trunk', 'primary']);
    final secondary = classes(['secondary', 'tertiary']);
    final minor = classes(['minor', 'service', 'track']);
    return {
      'version': 8,
      'name': 'Yalla 5roga ${dark ? 'Night' : 'Day'} $language',
      'glyphs': glyphsUrl,
      'transition': {'duration': 200, 'delay': 0},
      'sources': {
        'basemap': {
          'type': 'vector',
          'url': tileJsonUrl,
          'attribution': attribution,
        },
      },
      'layers': [
        {
          'id': 'land',
          'type': 'background',
          'paint': {'background-color': land},
        },
        fill(
          'green',
          'landcover',
          grass,
          filter: classes(['grass', 'wood', 'scrub']),
        ),
        fill('parks', 'park', park),
        fill(
          'gardens',
          'landuse',
          park,
          filter: classes(['garden', 'recreation_ground']),
        ),
        fill(
          'sports',
          'landuse',
          dark ? '#354B40' : '#D4E4D1',
          filter: classes(['pitch', 'stadium']),
        ),
        fill(
          'parking',
          'landuse',
          dark ? '#303638' : '#ECEEE9',
          filter: classes(['parking']),
          minzoom: 14,
        ),
        fill('water', 'water', water),
        line('waterways', 'waterway', water, width(.5, 2, 6)),
        {
          ...fill('buildings', 'building', building, minzoom: 13),
          'paint': {
            'fill-color': [
              'case',
              ['has', 'name'],
              dark ? '#424949' : '#DDE0DA',
              building,
            ],
            'fill-outline-color': outline,
          },
        },
        line(
          'minor-roads',
          'transportation',
          dark ? '#62696A' : '#FFFFFF',
          width(0, 1.5, 8),
          filter: minor,
          minzoom: 13,
        ),
        line(
          'secondary-casing',
          'transportation',
          dark ? '#424B4D' : '#DADDD6',
          width(.4, 4.5, 16),
          filter: secondary,
          minzoom: 9,
        ),
        line(
          'secondary-roads',
          'transportation',
          dark ? '#7D8584' : '#FFFFFF',
          width(.2, 3, 13),
          filter: secondary,
          minzoom: 9,
        ),
        line(
          'main-casing',
          'transportation',
          dark ? '#525453' : '#D8CDB6',
          width(1, 7, 23),
          filter: major,
        ),
        line(
          'main-roads',
          'transportation',
          dark ? '#BAAF91' : '#F6E6BF',
          width(.6, 5, 19),
          filter: major,
        ),
        line(
          'bridges-casing',
          'transportation',
          outline,
          width(1, 8, 25),
          filter: [
            'all',
            major,
            [
              '==',
              ['get', 'brunnel'],
              'bridge',
            ],
          ],
        ),
        line(
          'bridges',
          'transportation',
          dark ? '#C5BCA6' : '#FFF4D9',
          width(.7, 5.5, 20),
          filter: [
            'all',
            major,
            [
              '==',
              ['get', 'brunnel'],
              'bridge',
            ],
          ],
        ),
        {
          'id': 'building-heights',
          'type': 'fill-extrusion',
          'source': 'basemap',
          'source-layer': 'building',
          'minzoom': 16,
          'filter': [
            '>',
            [
              'coalesce',
              ['get', 'render_height'],
              0,
            ],
            0,
          ],
          'paint': {
            'fill-extrusion-color': building,
            'fill-extrusion-height': [
              'interpolate',
              ['linear'],
              ['zoom'],
              16,
              0,
              17,
              [
                'min',
                80,
                ['get', 'render_height'],
              ],
            ],
            'fill-extrusion-base': [
              'min',
              80,
              [
                'coalesce',
                ['get', 'render_min_height'],
                0,
              ],
            ],
            'fill-extrusion-opacity': .72,
            'fill-extrusion-vertical-gradient': false,
          },
        },
        label('nile-water-labels', 'water_name', 14, minzoom: 9),
        label('nile-river-labels', 'waterway', 14, minzoom: 10, road: true),
        label(
          'major-road-labels',
          'transportation_name',
          12,
          filter: major,
          minzoom: 12,
          road: true,
        ),
        label(
          'secondary-road-labels',
          'transportation_name',
          11,
          filter: secondary,
          minzoom: 16,
          road: true,
        ),
        label(
          'districts',
          'place',
          14,
          filter: classes(['suburb', 'quarter', 'neighbourhood']),
          minzoom: 10,
        ),
        label(
          'cities',
          'place',
          17,
          filter: classes(['city', 'town']),
          minzoom: 5,
        ),
        label(
          'landmarks',
          'poi',
          12,
          filter: classes(['monument', 'museum', 'attraction', 'castle']),
          minzoom: 14,
        ),
      ],
    };
  }
}
