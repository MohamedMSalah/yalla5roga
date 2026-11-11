import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';
import 'package:yalla_5roga/features/outings/data/datasources/outing_arrivals_remote_datasource.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_arrival.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outing_arrival_service.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_arrivals_section.dart';

const _id = 'outing-a';
const _user = 'member-a';

Position _position({
  double latitude = 30,
  double accuracy = 10,
  bool mocked = false,
}) => Position(
  longitude: 31,
  latitude: latitude,
  timestamp: DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
  isMocked: mocked,
);

OutingArrivalRoster _roster() => OutingArrivalRoster(
  arrivals: const [],
  unconfirmed: const [],
  open: true,
  closesAt: DateTime.now().add(const Duration(hours: 1)),
  opensAt: DateTime.now().subtract(const Duration(minutes: 1)),
  radiusMeters: 100,
  maxAccuracyMeters: 50,
  venue: (latitude: 30, longitude: 31),
);

class _Socket extends OutingChatSocketClient {
  _Socket()
    : super(
        baseUrl: 'http://test',
        tokenProvider: ({bool forceRefresh = false}) async => null,
      );

  final changes = StreamController<String>.broadcast();

  @override
  Stream<String> get arrivalChanges => changes.stream;

  @override
  Future<void> ensureConnected() async {}

  @override
  Future<void> dispose() async {
    await changes.close();
    await super.dispose();
  }
}

class _RosterSource extends OutingArrivalsRemoteDataSource {
  _RosterSource(super.client, this.load);

  final Future<OutingArrivalRoster> Function() load;

  @override
  Future<OutingArrivalRoster> list(String outingId) => load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('denied permission, disabled GPS, inaccurate and mocked fixes remain unverified', () async {
    var enabled = true;
    var permission = LocationPermission.denied;
    var fix = _position(accuracy: 51);
    var reads = 0;
    final writes = <Map<dynamic, dynamic>>[];
    final dio = Dio();
    addTearDown(dio.close);
    final socket = _Socket();
    addTearDown(socket.dispose);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          writes.add(request.data as Map);
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'data': {'arrived': true},
              },
            ),
          );
        },
      ),
    );
    final service = OutingArrivalService(
      OutingArrivalsRemoteDataSource(ApiClient(dio)),
      socket,
      locationEnabled: () async => enabled,
      checkPermission: () async => permission,
      requestPermission: () async => permission,
      getPosition: () async {
        reads++;
        return fix;
      },
    );
    var active = true;
    Future<ArrivalVerification> verify() => service.verify(
      _id,
      _roster(),
      isActive: () => active,
      shouldRequestPermission: () => true,
    );

    expect(await verify(), ArrivalVerification.unavailable);
    expect(reads, 0);
    enabled = false;
    permission = LocationPermission.whileInUse;
    expect(await verify(), ArrivalVerification.unavailable);
    expect(reads, 0);

    enabled = true;
    expect(await verify(), ArrivalVerification.unavailable);
    fix = _position(mocked: true);
    expect(await verify(), ArrivalVerification.unavailable);
    fix = _position(latitude: 30.001);
    expect(await verify(), ArrivalVerification.unverified);
    expect(writes, isEmpty);

    fix = _position(latitude: 30.00085);
    expect(await verify(), ArrivalVerification.arrived);
    expect(writes.single['method'], 'gps');
    expect(writes.single['captured_at'], isA<String>());
    active = false;
    expect(await verify(), ArrivalVerification.unverified);
    expect(writes, hasLength(1));
  });

  testWidgets(
    'resuming a visible outing rechecks location and a realtime event refreshes the roster',
    (tester) async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final dio = Dio();
      final socket = _Socket();
      addTearDown(dio.close);
      addTearDown(socket.dispose);
      var permission = LocationPermission.denied;
      var checks = 0;
      var requests = 0;
      var arrived = false;
      final start = DateTime.now().subtract(const Duration(minutes: 1));
      final end = start.add(const Duration(hours: 1));
      final remote = _RosterSource(ApiClient(dio), () async {
        requests++;
        return OutingArrivalRoster(
          arrivals: [
            if (arrived)
              OutingArrival(
                userId: _user,
                name: 'Ahmed',
                arrivedAt: DateTime.now(),
                method: 'gps',
              ),
          ],
          unconfirmed: [if (!arrived) (id: _user, name: 'Ahmed')],
          open: true,
          opensAt: start,
          closesAt: end,
          venue: (latitude: 30, longitude: 31),
          radiusMeters: 100,
          maxAccuracyMeters: 50,
        );
      });
      final service = OutingArrivalService(
        remote,
        socket,
        locationEnabled: () async => true,
        checkPermission: () async {
          checks++;
          return permission;
        },
        requestPermission: () async => permission,
        getPosition: () async => _position(latitude: 30.02),
      );
      final outing = Outing(
        id: _id,
        image: '',
        title: 'Plans',
        meta: '',
        date: '',
        status: OutingStatus.confirmed,
        scheduledAt: start,
        endsAt: end,
      );
      await tester.pumpWidget(
        Provider<OutingArrivalService>.value(
          value: service,
          child: MaterialApp(
            localizationsDelegates: const [L10n.delegate],
            home: Scaffold(
              body: OutingArrivalsSection(outing: outing, userId: _user),
            ),
          ),
        ),
      );
      Future<void> advance() async {
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
      }

      await tester.pumpAndSettle();
      expect(binding.lifecycleState, AppLifecycleState.resumed);
      expect(find.byType(OutingArrivalsSection), findsOneWidget);
      await advance();
      expect(requests, 1);
      expect(checks, 1);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 2));
      expect(checks, 1);

      permission = LocationPermission.whileInUse;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await advance();
      expect(checks, 2);
      expect(find.text('Not yet verified'), findsOneWidget);

      arrived = true;
      final previousRequests = requests;
      socket.changes.add(_id);
      await tester.pump();
      await advance();
      expect(requests, previousRequests + 1);
      expect(find.textContaining('Arrived ·'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
