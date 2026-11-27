import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/starting_location/domain/repositories/starting_location_repository.dart';
import 'package:yalla_5roga/features/starting_location/presentation/providers/starting_location_provider.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/starting_location/presentation/widgets/effective_starting_location_card.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

void main() {
  testWidgets('shows the temporary inputs and replaces them after reset', (
    tester,
  ) async {
    const temporary = EffectiveStartingLocation(
      status: EffectiveLocationStatus.ready,
      consentPolicyVersion: 'current',
      inputVersion: 2,
      name: 'Library',
      point: LatLng(30, 31),
      temporaryLocation: true,
      transportation: TransportationMode.walking,
      temporaryTransportation: true,
      override: StartingLocationOverride(
        source: OverrideLocationSource.savedPlace,
        referenceId: 'library',
      ),
    );
    const permanent = EffectiveStartingLocation(
      status: EffectiveLocationStatus.ready,
      consentPolicyVersion: 'current',
      inputVersion: 3,
      name: 'Home',
      point: LatLng(29, 32),
      transportation: TransportationMode.metro,
    );
    var value = temporary;
    var editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [L10n.delegate],
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) => EffectiveStartingLocationCard(
                  value: value,
                  onEdit: () => editCount++,
                  onReset: () => setState(() => value = permanent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Library · Temporary'), findsOneWidget);
    expect(find.text('Transportation · Walking · Temporary'), findsOneWidget);

    await tester.tap(find.text('Edit starting point'));
    expect(editCount, 1);
    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();

    expect(find.text('Home · Default'), findsOneWidget);
    expect(find.text('Transportation · Metro'), findsOneWidget);
    expect(find.text('Reset to default'), findsNothing);
  });

  test(
    'discards an in-flight outing response after the account changes',
    () async {
      const scope = (
        context: StartingLocationContext.outing,
        id: 'selected-outing',
      );
      final repository = _StartingLocationFixture();
      var currentAccount = true;
      final provider = StartingLocationProvider(
        repository,
        'first-account',
        scope,
        () => currentAccount,
      );
      addTearDown(provider.dispose);

      final pending = provider.reload();
      expect(repository.request, ('first-account', scope));
      currentAccount = false;
      repository.result.complete(
        const Right(
          EffectiveStartingLocation(
            status: EffectiveLocationStatus.ready,
            consentPolicyVersion: 'current',
            inputVersion: 2,
            name: 'Private location',
            point: LatLng(30, 31),
          ),
        ),
      );
      expect(await pending, isFalse);
      expect(provider.value, isNull);
    },
  );
}

class _StartingLocationFixture implements StartingLocationRepository {
  final result = Completer<Either<Failure, EffectiveStartingLocation>>();
  (String, StartingLocationScope)? request;

  @override
  Future<Either<Failure, EffectiveStartingLocation>> get(
    String account,
    StartingLocationScope scope,
  ) {
    request = (account, scope);
    return result.future;
  }

  @override
  Future<Either<Failure, EffectiveStartingLocation>> clear(
    String account,
    StartingLocationScope scope,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, EffectiveStartingLocation>> set(
    String account,
    StartingLocationScope scope,
    StartingLocationOverride override, {
    required String? consentPolicyVersion,
  }) => throw UnimplementedError();
}
