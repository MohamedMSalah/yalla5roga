import 'dart:async';

import 'package:yalla_5roga/core/config/app_config.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppConfig.initialize(AppConfig.testing());
  await testMain();
}
