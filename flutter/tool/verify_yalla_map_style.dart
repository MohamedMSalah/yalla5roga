import 'dart:convert';
import 'dart:io';

// Keep this pure-Dart exporter runnable directly by the VM without build hooks.
// ignore: avoid_relative_lib_imports
import '../lib/core/maps/yalla_map_style.dart';

// Pure Dart export for style-spec validation. Does not import or launch Flutter.
void main() {
  final variants = <String, dynamic>{};
  for (final dark in [false, true]) {
    for (final language in ['ar', 'en']) {
      final style = YallaMapStyle.build(dark: dark, language: language);
      final layers = style['layers'] as List;
      if ((style['sources'] as Map).values.any((s) => s['type'] != 'vector')) {
        throw StateError('Non-vector basemap');
      }
      if (layers.any((l) => l['type'] == 'raster')) {
        throw StateError('Raster layer');
      }
      if (layers.map((l) => l['id']).toSet().length != layers.length) {
        throw StateError('Duplicate layers');
      }
      variants['${dark ? 'dark' : 'light'}_$language'] = style;
    }
  }
  File('../docs/audit/MAPLIBRE_STYLES.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(variants)}\n',
  );
  stdout.writeln(
    'Exported four vector-only style variants for style-spec validation.',
  );
}
