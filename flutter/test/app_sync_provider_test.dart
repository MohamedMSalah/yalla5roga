import 'dart:async';

import 'package:yalla_5roga/core/network/realtime_change.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/network/app_sync_provider.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/chat/data/datasources/chat_send_queue.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';
import 'package:yalla_5roga/features/chat/presentation/providers/outing_chat_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  Completer<bool>? synchronizationGate;
  User? identity = const User(id: 'alice', name: 'Alice', phone: '');
  Completer<void>? refreshGate;
  @override
  User? get user => identity;
  @override
  Future<void> refreshProfile() async => refreshGate?.future;
  @override
  Future<bool> synchronizeRestoredAccount() async =>
      synchronizationGate?.future ?? false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Network extends Fake implements NetworkInfoImpl {
  bool online = false;
  final events = StreamController<bool>.broadcast();
  @override
  Future<bool> get isConnected async => online;
  @override
  Stream<bool> get changes => events.stream;
  void setOnline(bool value) {
    online = value;
    events.add(value);
  }
}

class _Socket extends Fake implements OutingChatSocketClient {
  @override
  int get sessionGeneration => 2;
  @override
  void setNetworkAvailable(bool online) {}
  Completer<bool>? reconcileGate;
  bool connected = true;
  final connections = StreamController<bool>.broadcast();
  final changes = StreamController<RealtimeChange>.broadcast();
  @override
  bool get isConnected => connected;
  @override
  Stream<bool> get connectionChanges => connections.stream;
  @override
  Stream<RealtimeChange> get dataChanges => changes.stream;
  @override
  Future<void> ensureConnected() async {}
  @override
  Future<bool> reconcileData() async => reconcileGate?.future ?? false;
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> syncGroups(Iterable<String> ids) async {}
}

class _Groups extends Fake implements GroupsProvider {
  final details = <String>[];
  @override
  Future<Group?> ensureGroupLoaded(
    String id, {
    bool forceRefresh = false,
    bool allowStale = true,
  }) async {
    details.add(id);
    return null;
  }

  int clears = 0;
  @override
  List<Group> get groups => const [];
  @override
  void clear() {
    clears++;
  }

  int previews = 0;
  int requests = 0;
  bool fail = false;
  @override
  Iterable<String> get openGroupIds => const [];
  @override
  Future<void> loadGroups({bool forceRefresh = false}) async {
    if (OfflineSnapshots.cacheOnly) {
      previews++;
      return;
    }
    requests++;
    if (fail) throw StateError('temporary failure');
  }
}

class _Outings extends Fake implements OutingsProvider {
  int liveChanges = 0;
  @override
  bool applyAttendanceChange(
    String id,
    String userId,
    AttendanceStatus status,
    DateTime updatedAt,
  ) {
    liveChanges++;
    return true;
  }

  int clears = 0;
  @override
  void clear() {
    clears++;
  }

  int requests = 0;
  final details = <String>[];
  @override
  Iterable<String> get openOutingIds => const [];
  @override
  bool containsOuting(String id) => true;
  @override
  Future<void> load({bool forceRefresh = false}) async {
    if (!OfflineSnapshots.cacheOnly) requests++;
  }

  @override
  Future<bool> refreshLifecycle({
    String? outingId,
    bool forceRefresh = false,
  }) async {
    details.add(outingId!);
    return true;
  }
}

class _Chat extends Fake implements OutingChatProvider {
  @override
  void clear() {}
  @override
  Future<void> recoverActiveChats() async {}
}

class _Inbox extends Fake implements NotificationsProvider {
  @override
  void clear() {}
  @override
  Future<void> refresh({bool forceRefresh = false}) async {}
}

class _Invitations extends Fake implements InvitationsProvider {
  @override
  void clear() {}
  @override
  void invalidate() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Network network;
  late _Socket socket;
  late _Groups groups;
  late _Outings outings;
  late AppSyncProvider sync;
  var disposed = false;

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    auth = _Auth();
    network = _Network();
    socket = _Socket();
    groups = _Groups();
    outings = _Outings();
    disposed = false;
    sync = AppSyncProvider(
      auth: auth,
      network: network,
      socket: socket,
      snapshots: OfflineSnapshots(prefs, () => auth.user?.id, 'backend'),
      queue: ChatSendQueue(prefs, () => auth.user?.id, 'backend'),
      flushSends: () async => false,
      chat: _Chat(),
      groups: groups,
      outings: outings,
      notifications: _Inbox(),
      invitations: _Invitations(),
    );
  }

  tearDown(() async {
    if (!disposed) sync.dispose();
    auth.dispose();
    await network.events.close();
    await socket.connections.close();
    await socket.changes.close();
  });

  testWidgets('logout cancels recovery and clears visible account state', (
    tester,
  ) async {
    await initialize();
    await sync.start();
    network.setOnline(true);
    await tester.pump();
    auth.identity = null;
    auth.notifyListeners();
    await tester.pump(const Duration(seconds: 3));
    expect(groups.clears, 1);
    expect(outings.clears, 1);
    expect(groups.requests, 0);
    expect(sync.status, SyncStatus.idle);
  });

  testWidgets(
    'hydrates offline then coalesces reconnect and targeted vote events',
    (tester) async {
      await initialize();
      await sync.start();
      expect(groups.previews, 1);
      expect(groups.requests, 0);
      expect(sync.status, SyncStatus.offline);
      network.setOnline(true);
      socket.connections.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(groups.requests, 1);
      expect(outings.requests, 1);
      for (var i = 0; i < 10; i++) {
        socket.changes.add(RealtimeChange(kind: 'outing', id: 'vote'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(outings.details, ['vote']);
      expect(outings.requests, 1);
      expect(groups.requests, 1);
    },
  );

  testWidgets('defers background events and catches up after resume', (
    tester,
  ) async {
    await initialize();
    await sync.start();
    sync.didChangeAppLifecycleState(AppLifecycleState.paused);
    network.setOnline(true);
    socket.changes.add(RealtimeChange(kind: 'membership', id: 'group'));
    await tester.pump(const Duration(seconds: 3));
    expect(groups.requests, 0);
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(groups.requests, 1);
    expect(outings.requests, 1);
  });

  testWidgets('retries a failed recovery with backoff', (tester) async {
    await initialize();
    await sync.start();
    groups.fail = true;
    network.setOnline(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(groups.requests, 1);
    expect(sync.status, SyncStatus.waiting);
    groups.fail = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(groups.requests, 2);
    expect(sync.status, SyncStatus.idle);
  });

  testWidgets('disposal during recovery ignores late callbacks', (
    tester,
  ) async {
    await initialize();
    await sync.start();
    socket.reconcileGate = Completer<bool>();
    network.setOnline(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    sync.dispose();
    disposed = true;
    socket.reconcileGate!.complete(false);
    await tester.pump();
    expect(groups.requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'caps failed catch-up retries and resumes on a fresh server event',
    (tester) async {
      await initialize();
      await sync.start();
      groups.fail = true;
      network.setOnline(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (final seconds in [1, 2, 4, 8, 16]) {
        await tester.pump(Duration(seconds: seconds));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(groups.requests, 6);
      await tester.pump(const Duration(minutes: 5));
      expect(groups.requests, 6);
      groups.fail = false;
      socket.changes.add(RealtimeChange(kind: 'group', id: 'group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(groups.requests, 7);
    },
  );

  testWidgets(
    'cached preview completes before a slow restored-account synchronization',
    (tester) async {
      await initialize();
      network.online = true;
      auth.synchronizationGate = Completer<bool>();
      final startup = sync.start();
      await tester.pump();
      expect(groups.previews, 1);
      expect(groups.requests, 0);
      auth.synchronizationGate!.complete(true);
      await startup;
      await tester.pump(const Duration(milliseconds: 300));
      expect(groups.requests, 1);
      expect(outings.requests, 1);
    },
  );

  testWidgets(
    'complete attendance applies immediately and new outing/group hints stay targeted',
    (tester) async {
      await initialize();
      await sync.start();
      network.setOnline(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final listRequests = outings.requests;
      final groupRequests = groups.requests;
      socket.changes.add(
        const RealtimeChange(
          kind: 'attendance',
          id: 'outing',
          payload: {
            'user_id': 'bob',
            'status': 'going',
            'updated_at': '2026-11-11T12:00:00Z',
          },
        ),
      );
      await tester.pump();
      expect(outings.liveChanges, 1);
      expect(outings.details, isEmpty);
      for (var i = 0; i < 10; i++) {
        socket.changes.add(const RealtimeChange(kind: 'outings', id: 'new'));
        socket.changes.add(
          const RealtimeChange(kind: 'group', id: 'new-group'),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(outings.details, ['new']);
      expect(groups.details, ['new-group']);
      expect(outings.requests, listRequests);
      expect(groups.requests, groupRequests);
    },
  );

  testWidgets(
    'late recovery from an old account cannot schedule reads for the new account',
    (tester) async {
      await initialize();
      await sync.start();
      final oldRefresh = Completer<void>();
      auth.refreshGate = oldRefresh;
      network.setOnline(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      auth.refreshGate = null;
      auth.identity = const User(id: 'bob', name: 'Bob', phone: '');
      auth.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(groups.clears, 1);
      final requests = groups.requests;
      oldRefresh.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(groups.requests, requests);
    },
  );

  testWidgets('queued events from a previous socket session are ignored', (
    tester,
  ) async {
    await initialize();
    await sync.start();
    network.setOnline(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    socket.changes.add(
      const RealtimeChange(kind: 'outing', id: 'old', session: 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(outings.details, isEmpty);
  });
}
