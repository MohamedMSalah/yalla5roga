import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';
import 'package:yalla_5roga/features/auth/domain/repositories/auth_repository.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/push_messaging_repository.dart';
import 'package:yalla_5roga/features/notifications/presentation/pages/notifications_page.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';

void main() {
  testWidgets(
    'cold-start tap waits for the authenticated shell and opens once',
    (tester) async {
      final payload = PushNotificationPayload.fromData({
        'type': 'system',
        'notificationId': 'inbox-item',
        'recipientUserId': 'member',
      });
      final messaging = _Messaging(payload);
      final inbox = _Inbox();
      final auth = _Auth();
      final fcm = FcmProvider(messaging: messaging);
      final notifications = NotificationsProvider(repository: inbox);
      addTearDown(fcm.dispose);
      addTearDown(notifications.dispose);
      addTearDown(auth.dispose);
      addTearDown(Get.reset);
      await notifications.refresh();

      final shell = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<NotificationsProvider>.value(
              value: notifications,
            ),
          ],
          child: GetMaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [L10n.delegate],
            builder: (context, child) {
              Responsive.init(context);
              return child!;
            },
            home: Scaffold(key: shell, body: const Text('Current page')),
          ),
        ),
      );
      await fcm.initialize();
      await tester.pump();
      expect(fcm.pendingTap, same(payload));
      expect(inbox.read, isEmpty);

      auth.user = const User(id: 'member', name: 'Member', phone: '');
      fcm.attachShell(shell.currentContext!);
      messaging.open(payload);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(inbox.read, ['inbox-item']);
      expect(fcm.pendingTap, isNull);

      Get.back<void>();
      await tester.pumpAndSettle();
      expect(find.text('Current page'), findsOneWidget);
      messaging.open(payload);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsNothing);
      expect(inbox.read, ['inbox-item']);
    },
  );
}

class _Auth extends AuthProvider {
  _Auth() : super(repository: _AuthRepository());

  @override
  User? user;

  @override
  bool get isAuthenticated => user != null;
}

class _AuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messaging implements PushMessagingRepository {
  _Messaging(this.initial);

  final PushNotificationPayload initial;
  late void Function(PushNotificationPayload) open;

  @override
  Future<void> initialize({
    required void Function(PushNotificationPayload) onOpened,
  }) async => open = onOpened;

  @override
  String? get token => null;

  @override
  Stream<String?> get tokenStream => const Stream.empty();

  @override
  Future<PushNotificationPayload?> takeInitialMessage() async => initial;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Inbox implements NotificationsRepository {
  final read = <String>[];

  @override
  Future<Either<Failure, NotificationsFeed>> getNotifications({
    bool forceRefresh = false,
  }) async => const Right(NotificationsFeed(unreadCount: 0, items: []));

  @override
  Future<Either<Failure, int>> markRead(String id) async {
    read.add(id);
    return const Right(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
