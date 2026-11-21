import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> persistMapStyle(String style, String variant) async {
  final directory = await getApplicationSupportDirectory();
  final file = File.fromUri(directory.uri.resolve('yalla-map-$variant.json'));
  if (!await file.exists()) {
    final temporary = await File('${file.path}.tmp')
        .writeAsString(style, flush: true);
    await temporary.rename(file.path);
  }
  return file.uri.toString();
}
