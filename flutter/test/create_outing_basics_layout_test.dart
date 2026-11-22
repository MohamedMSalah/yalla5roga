import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/responsive/responsive.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_basics_step.dart';

void main() {
  for (final (locale, size, brightness) in [
    (const Locale('ar'), const Size(320, 740), Brightness.dark),
    (const Locale('en'), const Size(760, 900), Brightness.light),
  ]) {
    testWidgets('occasion picker updates cover in ${locale.languageCode}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l10n = L10n(locale);
      final form = CreateOutingProvider(
        groups: const [],
        contacts: const [],
        catalogPlaces: const [],
        specialEventImage: (_) => '',
        specialEvent: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          theme: ThemeData(brightness: brightness),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            Responsive.init(context);
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            );
          },
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListenableBuilder(
                  listenable: form,
                  builder: (context, _) => CreateOutingBasicsStep(
                    form: form..syncLocale(l10n),
                    onInviteGuests: () {},
                    onPickGroup: () {},
                    onPickSchedule: () {},
                    onPickDeadline: () {},
                    onEditLocation: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cover = find.byType(PlanningCover);
      expect(
        tester.widget<PlanningCover>(cover).art,
        PlanningCoverArt.birthday,
      );
      final wedding = find.widgetWithText(ChoiceChip, l10n.wedding);
      await tester.ensureVisible(wedding);
      await tester.pumpAndSettle();
      expect(wedding.hitTestable(), findsOneWidget);
      await tester.tap(wedding.hitTestable());
      await tester.pumpAndSettle();
      expect(form.occasion, OutingOccasion.wedding);
      expect(tester.widget<PlanningCover>(cover).art, PlanningCoverArt.wedding);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      form.dispose();
    });
  }
}
