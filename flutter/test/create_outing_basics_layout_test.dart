import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/responsive/responsive.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/create_outing_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_basics_step.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/create_outing_location_step.dart';

void main() {
  testWidgets('place voting selects catalog and map candidates in one step', (
    tester,
  ) async {
    final form = CreateOutingProvider(
      groups: const [],
      contacts: const [],
      catalogPlaces: const [
        Place(id: 'cafe', name: 'Cafe', area: 'Cairo'),
        Place(id: 'bistro', name: 'Bistro', area: 'Cairo'),
      ],
      specialEventImage: (_) => '',
    );
    addTearDown(form.dispose);
    const l10n = L10n(Locale('en'));

    Future<void> show(WidgetBuilder buildStep) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [L10n.delegate],
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: form,
                builder: (context, _) => buildStep(context),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(
      (_) => CreateOutingBasicsStep(
        form: form,
        onUploadPhoto: () async {},
        onInviteGuests: () {},
        onPickGroup: () {},
        onPickDate: () {},
        onPickTime: () {},
      ),
    );
    expect(find.text(l10n.addPlacesForVoting), findsNothing);

    await show(
      (_) => CreateOutingLocationStep(
        form: form,
        onPickCustomLocation: () => form.addSelectedPlace(
          Place(
            area: '',
            latitude: 30.04 + form.selectedPlaces.length / 100,
            longitude: 31.23,
            name: 'Map pin',
          ),
        ),
      ),
    );
    await tester.tap(find.text(l10n.addPlacesForVoting));
    await tester.pumpAndSettle();
    expect(form.multiPlaceMode, isTrue);
    expect(find.text(l10n.voteDeadlineHours), findsNothing);
    for (final label in [
      'Cafe',
      'Bistro',
      l10n.mapManagePlaces,
      l10n.mapManagePlaces,
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(form.selectedPlaces.map((place) => place.name), [
      'Cafe',
      'Bistro',
      'Map pin',
      'Map pin',
    ]);
    final restored = OutingDraft.fromJson(form.toDraft().toJson());
    expect(restored.selectedPlaces.map((place) => place.id), [
      'cafe',
      'bistro',
      '',
      '',
    ]);
    expect(
      restored.selectedPlaces[2].latitude,
      isNot(restored.selectedPlaces[3].latitude),
    );

    await tester.tap(find.text(l10n.useSingleLocation));
    await tester.pumpAndSettle();
    expect(form.multiPlaceMode, isFalse);
    expect(find.text(l10n.pickOnMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      addTearDown(form.dispose);

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
                    onUploadPhoto: () async {},
                    onInviteGuests: () {},
                    onPickGroup: () {},
                    onPickDate: () {},
                    onPickTime: () {},
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
      await tester.tap(find.widgetWithText(ChoiceChip, l10n.wedding));
      await tester.pumpAndSettle();
      expect(form.occasion, OutingOccasion.wedding);
      expect(tester.widget<PlanningCover>(cover).art, PlanningCoverArt.wedding);
      expect(tester.takeException(), isNull);
    });
  }
}
