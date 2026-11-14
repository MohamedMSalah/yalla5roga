import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> persistMapStyle(String style, String variant) async {
  final directory = await getApplicationSupportDirectory();
  final file = File.fromUri(directory.uri.resolve('yalla-map-$variant.json'));
  await file.writeAsString(style, flush: true);
  return file.uri.toString();
}
