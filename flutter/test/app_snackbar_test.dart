import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/responsive/responsive.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    for (final wide in [false, true]) {
      testWidgets(
        'branded snackbar $locale ${wide ? 'wide dark' : 'phone light'}',
        (tester) async {
          tester.view.physicalSize = wide
              ? const Size(800, 900)
              : const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l10n = L10n(Locale(locale));
          var settingsOpened = false;
          await tester.pumpWidget(
            GetMaterialApp(
              locale: Locale(locale),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                L10n.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: ThemeData(
                brightness: wide ? Brightness.dark : Brightness.light,
              ),
              builder: (context, child) {
                Responsive.init(context);
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(wide ? 2 : 1)),
                  child: child!,
                );
              },
              home: Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => AppSnackBar.showError(
                      l10n.recoveryUnavailable,
                      actionLabel: l10n.openAppSettings,
                      onAction: () => settingsOpened = true,
                    ),
                    child: const Text('Show'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Show'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(SvgPicture), findsOneWidget);
          expect(find.text(l10n.recoveryUnavailable), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(l10n.openAppSettings));
          await tester.pumpAndSettle();
          expect(settingsOpened, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
          Get.reset();
        },
      );
    }
  }
}
