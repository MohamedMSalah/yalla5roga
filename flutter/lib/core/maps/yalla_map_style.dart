import 'dart:convert';

/// OpenMapTiles schema only; no provider-specific behavior in the map UI.
abstract final class YallaMapStyle {
  static const _defaultTiles = 'https://tiles.openfreemap.org/planet/latest';
  static const _defaultGlyphs =
      'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';
  static const tileJsonUrl = String.fromEnvironment(
    'MAP_VECTOR_TILEJSON_URL',
    defaultValue: _defaultTiles,
  );
  static const glyphsUrl = String.fromEnvironment(
    'MAP_GLYPHS_URL',
    defaultValue: _defaultGlyphs,
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
    defaultValue:
        tileJsonUrl == _defaultTiles &&
        glyphsUrl == _defaultGlyphs &&
        lightStyleUrl == '' &&
        darkStyleUrl == '',
  );
  static const font = 'Noto Sans Regular';

  static final _styles = <(bool, String), String>{};
  static String resolve({required bool dark, required String language}) =>
      _styles.putIfAbsent((dark, language), () => _resolve(dark, language));

  static String _resolve(bool dark, String language) {
    final override = dark ? darkStyleUrl : lightStyleUrl;
    return override.isNotEmpty
        ? override.replaceAll('{language}', language == 'ar' ? 'ar' : 'en')
        : jsonEncode(build(dark: dark, language: language));
  }

  static Map<String, dynamic> build({
    required bool dark,
    required String language,
  }) {
    final land = dark ? '#0D1424' : '#F7F8F4';
    final water = dark ? '#083D5B' : '#A9DCEB';
    final park = dark ? '#102B29' : '#CFE8CF';
    final grass = dark ? '#142925' : '#DDEDD6';
    final building = dark ? '#1B2638' : '#E8E9E6';
    final outline = dark ? '#29354B' : '#D5D8D4';
    final ink = dark ? '#B9B8D7' : '#414D4C';
    final halo = dark ? '#0D1424' : '#F7F8F4';
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
      bool landmark = false,
      String? color,
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
        if (landmark) ...{
          'icon-image': [
            'case',
            classes(['university', 'college', 'school']),
            'yalla-landmark_school',
            'yalla-landmark_culture',
          ],
          'icon-size': .58,
          'icon-optional': true,
          'text-anchor': 'top',
          'text-offset': [0, .75],
        },
      },
      'paint': {
        'text-color': color ?? ink,
        'text-halo-color': halo,
        'text-halo-width': 1.4,
      },
    };
    final major = classes(['motorway', 'trunk', 'primary']);
    final secondary = classes(['secondary', 'tertiary']);
    final minor = classes(['service', 'track', 'path']);
    final residential = classes(['minor']);
    final highways = classes(['motorway', 'trunk']);
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
        if (dark)
          fill(
            'urban-blocks',
            'landuse',
            '#141D2E',
            filter: classes([
              'residential',
              'commercial',
              'industrial',
              'retail',
            ]),
          ),
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
          dark ? '#19332E' : '#D4E4D1',
          filter: classes(['pitch', 'stadium']),
        ),
        fill(
          'parking',
          'landuse',
          dark ? '#182232' : '#ECEEE9',
          filter: classes(['parking']),
          minzoom: 14,
        ),
        fill('water', 'water', water),
        if (dark)
          fill('deep-water', 'water', '#073451', filter: classes(['ocean'])),
        line('waterways', 'waterway', water, width(.5, 2, 6)),
        {
          ...fill('buildings', 'building', building, minzoom: 13),
          'paint': {
            'fill-color': building,
            if (!dark) 'fill-outline-color': outline,
          },
        },
        line(
          'minor-roads',
          'transportation',
          dark ? '#29354B' : '#FFFFFF',
          dark ? width(0, .65, 4) : width(0, 1, 6),
          filter: minor,
          minzoom: 13,
        ),
        line(
          'residential-roads',
          'transportation',
          dark ? '#354055' : '#FFFFFF',
          width(0, .9, 6),
          filter: residential,
          minzoom: 12,
        ),
        line(
          'secondary-casing',
          'transportation',
          dark ? '#29354B' : '#DADDD6',
          width(.4, 4.5, 16),
          filter: secondary,
          minzoom: 9,
        ),
        line(
          'secondary-roads',
          'transportation',
          dark ? '#485269' : '#FFFFFF',
          width(.2, 3, 13),
          filter: secondary,
          minzoom: 9,
        ),
        line(
          'main-casing',
          'transportation',
          dark ? '#53505C' : '#D8CDB6',
          width(1, 7, 23),
          filter: major,
        ),
        line(
          'main-roads',
          'transportation',
          dark ? '#77705E' : '#F6E6BF',
          width(.6, 5, 19),
          filter: major,
        ),
        if (dark)
          line(
            'highway-highlights',
            'transportation',
            '#8A7C60',
            width(.45, 3.8, 16),
            filter: highways,
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
          dark ? '#8A7C60' : '#FFF4D9',
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
        label(
          'water-labels',
          'water_name',
          14,
          minzoom: 9,
          color: dark ? '#7FB5DB' : null,
        ),
        label(
          'river-labels',
          'waterway',
          14,
          minzoom: 10,
          road: true,
          color: dark ? '#7FB5DB' : null,
        ),
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
          filter: [
            'any',
            classes(['monument', 'museum', 'castle', 'university', 'college']),
            [
              'in',
              ['get', 'subclass'],
              [
                'literal',
                [
                  'monument',
                  'museum',
                  'castle',
                  'university',
                  'college',
                  'memorial',
                ],
              ],
            ],
          ],
          minzoom: 13,
          landmark: true,
        ),
      ],
    };
  }
}
