import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_preferences.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/entities/meetup_session.dart';
import 'package:yalla_5roga/features/smart_meetup/domain/repositories/smart_meetup_repository.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/providers/smart_meetup_provider.dart';
import 'package:yalla_5roga/features/smart_meetup/presentation/widgets/meetup_preferences_summary.dart';

void main() {
  testWidgets('preferences and reset stay local until Apply', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MeetupFixture();
    final provider = SmartMeetupProvider.standalone(repository, 'account');
    addTearDown(provider.dispose);
    await provider.open();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [L10n.delegate],
        home: Scaffold(
          body: ListenableBuilder(
            listenable: provider,
            builder: (context, _) => MeetupPreferencesSummary(
              provider: provider,
              session: provider.session!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    final open = find.widgetWithText(ListTile, 'Meetup preferences');
    final close = find.byTooltip('Close');
    final apply = find.widgetWithText(FilledButton, 'Apply Preferences');
    final reset = find.widgetWithText(TextButton, 'Reset');
    final affordable = find.widgetWithText(FilterChip, r'$  Affordable');
    final moderate = find.widgetWithText(FilterChip, r'$$  Moderate');

    expect(find.widgetWithText(Chip, 'Balanced'), findsOneWidget);
    await tap(open);
    await tap(affordable);
    await tap(close);
    expect(repository.writes, 0);
    expect(find.widgetWithText(Chip, r'$  Affordable'), findsNothing);

    await tap(open);
    await tap(find.text('Place category'));
    await tap(find.widgetWithText(FilterChip, 'Museums'));
    await tap(affordable);
    await tap(moderate);
    await tap(find.widgetWithText(ChoiceChip, '4.5+'));
    await tap(
      find.widgetWithText(RadioListTile<TravelFairnessMode>, 'Equal Travel'),
    );
    await tap(find.widgetWithText(ChoiceChip, '45 min'));
    for (final label in ['Top Rated', 'Budget Friendly', 'Shortest Distance']) {
      await tap(find.widgetWithText(FilterChip, label));
    }
    await tap(apply);
    expect(repository.writes, 1);
    expect(repository.current.categoryIds, {'museums'});
    expect(repository.current.budgetLevels, {
      BudgetLevel.affordable,
      BudgetLevel.moderate,
    });
    expect(repository.current.minimumRating, 4.5);
    expect(repository.current.maximumTravelDurationSeconds, 2700);
    expect(
      repository.current.travelFairnessMode,
      TravelFairnessMode.equalTravel,
    );
    expect(
      repository.current.additionalPriorities,
      OptimizationPriority.values.toSet(),
    );
    expect(find.widgetWithText(Chip, 'Museums'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Equal Travel'), findsOneWidget);

    await tap(open);
    await tap(reset);
    expect(repository.writes, 1);
    await tap(close);
    expect(find.widgetWithText(Chip, 'Equal Travel'), findsOneWidget);
    await tap(open);
    await tap(reset);
    await tap(apply);
    expect(repository.resets, 1);
    expect(find.widgetWithText(Chip, 'Balanced'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Museums'), findsNothing);
  });
}

class _MeetupFixture implements SmartMeetupRepository {
  var writes = 0;
  var resets = 0;
  var current = const MeetupPreferences();

  MeetupSession get _session => MeetupSession(
    id: 'session',
    status: MeetupSessionStatus.active,
    calculation: MeetupCalculationStatus.routingUnavailable,
    preferences: current,
    inputVersion: 1 + writes + resets,
    expiresAt: DateTime.utc(2026, 11, 28),
    canManage: true,
    readiness: null,
  );

  @override
  Future<Either<Failure, MeetupSession>> openStandalone(String account) async =>
      Right(_session);

  @override
  Future<Either<Failure, List<MeetupCategoryOption>>> filterOptions(
    String account,
  ) async => const Right([MeetupCategoryOption('museums', 'Museums', 'متاحف')]);

  @override
  Future<Either<Failure, MeetupSession>> update(
    String account,
    String id,
    MeetupPreferences preferences,
  ) async {
    writes++;
    current = preferences;
    return Right(_session);
  }

  @override
  Future<Either<Failure, MeetupSession>> resetPreferences(
    String account,
    String id,
  ) async {
    resets++;
    current = const MeetupPreferences();
    return Right(_session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
