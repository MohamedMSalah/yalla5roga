import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yalla_5roga/app.dart';
import 'package:yalla_5roga/core/di/app_dependencies.dart';
import 'package:yalla_5roga/core/monitoring/analytics_service.dart';
import 'package:yalla_5roga/core/monitoring/crashlytics_service.dart';
import 'package:yalla_5roga/core/monitoring/performance_service.dart';
import 'package:yalla_5roga/core/monitoring/startup_trace.dart';
import 'package:yalla_5roga/features/notifications/data/services/fcm_background_handler.dart';
import 'package:yalla_5roga/firebase_options.dart';

Future<void> main() async {
  StartupTrace.start();
  StartupTrace.mark('main');
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Crashlytics stays on the pre-frame path so startup crashes are reported.
      await CrashlyticsService.instance.initialize();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(CrashlyticsService.instance.recordFlutterFatalError(details));
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(
          CrashlyticsService.instance.recordError(
            error,
            stack,
            reason: 'platform_dispatcher',
            fatal: true,
          ),
        );
        return true;
      };

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final deps = await AppDependencies.create();
      final userId = deps.auth.user?.id;
      unawaited(CrashlyticsService.instance.setUserId(userId));

      // Analytics and Performance are not needed to choose splash vs home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        StartupTrace.mark('first_frame');
        unawaited(_startMonitoring(userId));
      });

      StartupTrace.mark('run_app');
      runApp(App(deps: deps));
    },
    (error, stack) {
      debugPrint('[ZonedError] $error\n$stack');
      unawaited(
        CrashlyticsService.instance.recordError(
          error,
          stack,
          reason: 'runZonedGuarded',
          fatal: true,
        ),
      );
    },
  );
}

Future<void> _startMonitoring(String? userId) async {
  try {
    await Future.wait<void>([
      AnalyticsService.instance.initialize(),
      PerformanceService.instance.initialize(),
    ]);
    await AnalyticsService.instance.setUserId(userId);
  } catch (error, stack) {
    debugPrint('[Startup] monitoring init failed: $error\n$stack');
  }
  StartupTrace.mark('monitoring_ready');
}
