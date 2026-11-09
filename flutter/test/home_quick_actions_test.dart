import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/quick_actions.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'Home actions remain available without invite in ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l10n = L10n(locale);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: const [
              L10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(child: QuickActions()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.newOuting), findsOneWidget);
        expect(find.text(l10n.specialEvent), findsOneWidget);
        expect(find.text(l10n.newGroup), findsOneWidget);
        expect(find.text(l10n.inviteFriends), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
