import 'package:yalla_5roga/features/outings/presentation/providers/saved_outings_provider.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:yalla_5roga/core/cache/offline_snapshots.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/realtime_change.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/chat/data/datasources/chat_send_queue.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';
import 'package:yalla_5roga/features/chat/presentation/providers/outing_chat_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

enum SyncStatus { idle, offline, reconnecting, syncing, waiting }

/// Owns one set of listeners for the signed-in app and coalesces REST catch-up.
class AppSyncProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppSyncProvider({
    required this.auth,
    required this.network,
    required this.socket,
    required this.snapshots,
    required this.queue,
    required this.flushSends,
    required this.chat,
    required this.groups,
    required this.outings,
    required this.notifications,
    required this.invitations,
    this.clearMediaCache,
    this.savedOutings,
  }) {
    auth.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    _networkSub = network.changes.listen(_networkChanged);
    _socketSub = socket.connectionChanges.listen(_socketChanged);
    _dataSub = socket.dataChanges.listen(_dataChanged);
  }

  final SavedOutingsProvider? savedOutings;
  final AuthProvider auth;
  final NetworkInfoImpl network;
  final OutingChatSocketClient socket;
  final OfflineSnapshots snapshots;
  final ChatSendQueue queue;
  final Future<bool> Function() flushSends;
  final OutingChatProvider chat;
  final GroupsProvider groups;
  final OutingsProvider outings;
  final NotificationsProvider notifications;
  final InvitationsProvider invitations;

  /// Clears account-scoped media URL metadata and private image caches when
  /// the signed-in account changes (including token revocation).
  final Future<void> Function(String uid)? clearMediaCache;
  late final StreamSubscription<bool> _networkSub;
  late final StreamSubscription<bool> _socketSub;
  late final StreamSubscription<RealtimeChange> _dataSub;

  String? _uid;
  int _generation = 0;
  bool _online = true;
  bool _foreground = true;
  bool _working = false;
  bool _disposed = false;
  bool _sending = false;
  bool _catchUp = false;
  bool _needsSocketCatchUp = true;
  bool _socketConnected = false;
  Future<void>? _recovering;
  bool _groupsDirty = false;
  bool _outingsDirty = false;
  bool _profileDirty = false;
  bool _inboxDirty = false;
  bool _chatDirty = false;
  final _groupIds = <String>{};
  final _outingIds = <String>{};
  final _activeGroupIds = <String>{};
  final _activeOutingIds = <String>{};
  Timer? _debounce;
  Timer? _retry;
  Timer? _syncRetry;
  int _syncAttempt = 0;
  int _attempt = 0;
  DateTime? _lastCatchUp;
  Future<void>? _startup;

  SyncStatus get status {
    if (_uid == null || !_foreground) return SyncStatus.idle;
    if (!_online) return SyncStatus.offline;
    if (_working || _sending) return SyncStatus.syncing;
    if (_retry != null || _syncRetry != null) return SyncStatus.waiting;
    return socket.isConnected ? SyncStatus.idle : SyncStatus.reconnecting;
  }

  Future<void> start() {
    _accountChanged();
    return _startup ?? Future.value();
  }

  void _accountChanged() {
    if (_disposed) return;
    final uid = auth.user?.id;
    if (uid == _uid) return;
    final previous = _uid;
    _uid = uid;
    final generation = ++_generation;
    _working = false;
    _sending = false;
    _debounce?.cancel();
    _retry?.cancel();
    _retry = null;
    _syncRetry?.cancel();
    _syncRetry = null;
    _syncAttempt = 0;
    _attempt = 0;
    _needsSocketCatchUp = true;
    _socketConnected = false;
    _recovering = null;
    _lastCatchUp = null;
    _catchUp = _groupsDirty = _outingsDirty = _profileDirty = _inboxDirty =
        _chatDirty = false;
    _groupIds.clear();
    _outingIds.clear();
    _activeGroupIds.clear();
    _activeOutingIds.clear();
    if (previous != null) {
      savedOutings?.clear();
      groups.clear();
      outings.clear();
      chat.clear();
      notifications.clear();
      invitations.clear();
      unawaited(snapshots.clear(previous));
      unawaited(queue.clear(previous));
      unawaited(socket.disconnect());
      final clearMedia = clearMediaCache;
      if (clearMedia != null) unawaited(clearMedia(previous));
    }
    _startup = uid == null ? null : _initialize(uid, generation);
    notifyListeners();
  }

  Future<void> _initialize(String uid, int generation) async {
    await OfflineSnapshots.preview(
      () => Future.wait([
        groups.loadGroups(),
        outings.load(),
        if (savedOutings != null) savedOutings!.syncDrafts(),
      ]),
    );
    final online = await network.isConnected;
    if (_disposed || (_uid != uid || generation != _generation)) return;
    _online = online;
    socket.setNetworkAvailable(online);
    _catchUp = true;
    _profileDirty = true;
    notifyListeners();
    if (!_online || !_foreground) return;
    await _recoverData();
    if (_disposed || generation != _generation) return;
    await _sync();
    if ((_uid == uid && generation == _generation)) sendsChanged();
  }

  void _networkChanged(bool online) {
    if (_disposed) return;
    if (_online == online) return;
    _online = online;
    socket.setNetworkAvailable(online);
    if (_uid == null) return;
    notifyListeners();
    if (!online) {
      _debounce?.cancel();
      _retry?.cancel();
      _retry = null;
      _syncRetry?.cancel();
      _syncRetry = null;
      return;
    }
    _recover();
  }

  void _socketChanged(bool connected) {
    if (_disposed || _uid == null) return;
    final transportConnected = socket.isConnected;
    if (_socketConnected == transportConnected) return;
    _socketConnected = transportConnected;
    notifyListeners();
    if (!transportConnected) {
      _needsSocketCatchUp = true;
      return;
    }
    unawaited(_recoverData());
    if (_retry != null) sendsChanged();
  }

  Future<void> _recoverData() {
    final generation = _generation;
    return _recovering ??= _reconcile().whenComplete(() {
      if (_generation == generation) _recovering = null;
    });
  }

  Future<void> _reconcile() async {
    final uid = _uid;
    final generation = _generation;
    final chatMayBeStale = _needsSocketCatchUp || !socket.isConnected;
    var replayed = false;
    try {
      final synchronized = await auth.synchronizeRestoredAccount();
      if (_disposed || (_uid != uid || generation != _generation)) return;
      if (synchronized) {
        _groupsDirty = _outingsDirty = true;
        // Synchronization returned the canonical profile already.
        _profileDirty = false;
      }
      await savedOutings?.syncDrafts();
      await socket.ensureConnected();
      if (_disposed || (_uid != uid || generation != _generation)) return;
      replayed = await socket.reconcileData();
    } catch (error) {
      if (!_disposed && (_uid == uid && generation == _generation)) {
        retrySynchronization();
      }
    }
    if (_disposed ||
        (_uid != uid || generation != _generation) ||
        !_foreground) {
      return;
    }
    _catchUp = _catchUp || !replayed;
    _needsSocketCatchUp = !replayed;
    if (!replayed) {
      // A server restart/expired cursor invalidates these account snapshots
      // even when their normal TTL has not elapsed. Catalogs/saved data stay put.
      _groupsDirty = _outingsDirty = _inboxDirty = true;
    }
    // Chat messages themselves are not journaled: only the active threads
    // need history recovery after a transport gap.
    _chatDirty = _chatDirty || chatMayBeStale || !replayed;
    _scheduleSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      unawaited(_resume());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _debounce?.cancel();
      _retry?.cancel();
      _retry = null;
      _syncRetry?.cancel();
      _syncRetry = null;
      notifyListeners();
    }
  }

  Future<void> _resume() async {
    final generation = _generation;
    final online = await network.isConnected;
    if (_disposed ||
        generation != _generation ||
        !_foreground ||
        _uid == null) {
      return;
    }
    _online = online;
    socket.setNetworkAvailable(online);
    notifyListeners();
    _recover();
  }

  void _recover() {
    if (!_foreground || !_online || _uid == null) return;
    _syncAttempt = 0;
    unawaited(_recoverData());
    sendsChanged();
  }

  void _dataChanged(RealtimeChange event) {
    if (_disposed || _uid == null) return;
    if (event.session != null && event.session != socket.sessionGeneration) {
      return;
    }
    if (_syncAttempt > 5) _syncAttempt = 0;
    switch (event.kind) {
      case 'membership':
        _chatDirty = true;
        _outingsDirty = true;
        _groupsDirty = true;
        invitations.invalidate();
        if (event.id case final id?) {
          _groupIds.add(id);
        }
      case 'group':
        invitations.invalidate();
        if (event.id == null) _groupsDirty = true;
        if (event.id case final id?) {
          _groupIds.add(id);
        }
      case 'outings':
        if (event.id == null) _outingsDirty = true;
        if (event.id case final id?) {
          _outingIds.add(id);
        }
      case 'attendance':
        final data = event.payload;
        final userId = data?['user_id'];
        final at = DateTime.tryParse(data?['updated_at']?.toString() ?? '');
        final status = switch (data?['status']) {
          'going' => AttendanceStatus.going,
          'not_going' => AttendanceStatus.notGoing,
          'maybe' => AttendanceStatus.maybe,
          _ => null,
        };
        if (event.id != null &&
            userId is String &&
            at != null &&
            status != null &&
            outings.applyAttendanceChange(event.id!, userId, status, at)) {
          return;
        }
        if (event.id case final id?) _outingIds.add(id);
      case 'outing':
        if (event.id case final id?) {
          _outingIds.add(id);
        }
      case 'profile':
        _profileDirty = true;
      case 'inbox':
        _inboxDirty = true;
      default:
        return;
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_disposed ||
        _uid == null ||
        !_foreground ||
        !_online ||
        _syncRetry != null ||
        _syncAttempt > 5 ||
        _debounce?.isActive == true) {
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_sync()),
    );
  }

  Future<void> _sync() async {
    final uid = _uid;
    final generation = _generation;
    if (_disposed || _working || uid == null || !_foreground || !_online) {
      return;
    }
    if (!_catchUp &&
        !_groupsDirty &&
        !_outingsDirty &&
        !_profileDirty &&
        !_inboxDirty &&
        !_chatDirty &&
        _groupIds.isEmpty &&
        _outingIds.isEmpty) {
      return;
    }

    // A resume and the ensuing socket handshake are one recovery.
    final lastCatchUp = _lastCatchUp;
    final full =
        _catchUp &&
        (lastCatchUp == null ||
            socket.isConnected && _needsSocketCatchUp ||
            DateTime.now().difference(lastCatchUp) >
                const Duration(seconds: 2));
    if (full && socket.isConnected) _needsSocketCatchUp = false;
    _catchUp = false;
    final forceGroups = _groupsDirty;
    final forceOutings = _outingsDirty;
    final forceInbox = _inboxDirty;
    final loadGroups = full || _groupsDirty;
    final loadOutings = full || _outingsDirty;
    final profile = _profileDirty;
    final inbox = full || _inboxDirty;
    final chatChanged = full || _chatDirty;
    final groupIds = {..._groupIds, if (full) ...groups.openGroupIds};
    final outingIds = {..._outingIds, if (full) ...outings.openOutingIds};
    _groupsDirty = _outingsDirty = _profileDirty = _inboxDirty = _chatDirty =
        false;
    _groupIds.clear();
    _outingIds.clear();
    if (!loadGroups &&
        !loadOutings &&
        !profile &&
        !inbox &&
        !chatChanged &&
        groupIds.isEmpty &&
        outingIds.isEmpty) {
      return;
    }
    _working = true;
    _activeGroupIds.addAll(groupIds);
    _activeOutingIds.addAll(outingIds);
    notifyListeners();

    try {
      if (profile) await auth.refreshProfile();
      if (_disposed || (_uid != uid || generation != _generation)) return;
      await Future.wait([
        if (inbox) notifications.refresh(forceRefresh: forceInbox),
        if (loadGroups) groups.loadGroups(forceRefresh: forceGroups),
        if (loadOutings) outings.load(forceRefresh: forceOutings),
        if (chatChanged) chat.recoverActiveChats(),
      ]);
      if (_disposed || (_uid != uid || generation != _generation)) return;

      await Future.wait([
        for (final id in groupIds)
          groups.ensureGroupLoaded(id, forceRefresh: true),
        for (final id in outingIds) ...[
          outings.refreshLifecycle(outingId: id, forceRefresh: true),
          outings.loadGuests(id),
        ],
      ]);
      if (_disposed || (_uid != uid || generation != _generation)) return;
      unawaited(socket.syncGroups(groups.groups.map((group) => group.id)));
      if (full && (_uid == uid && generation == _generation)) {
        _lastCatchUp = DateTime.now();
      }
      // A cached fallback can complete successfully while onReadFailure has
      // queued another catch-up. Do not reset the cap in that case.
      if (_syncRetry == null && !_catchUp) _syncAttempt = 0;
    } catch (error) {
      // Background callbacks must not leak an unhandled Future error or lose
      // the invalidations removed from the pending sets above.
      debugPrint('[sync] Catch-up failed: ${error.runtimeType}');
      if (!_disposed && (_uid == uid && generation == _generation)) {
        _groupIds.addAll(groupIds);
        _outingIds.addAll(outingIds);
        retrySynchronization();
      }
    } finally {
      if (generation == _generation) {
        _activeGroupIds.clear();
        _activeOutingIds.clear();
        _working = false;
        notifyListeners();
        if (_catchUp ||
            _groupsDirty ||
            _outingsDirty ||
            _profileDirty ||
            _inboxDirty ||
            _chatDirty ||
            _groupIds.isNotEmpty ||
            _outingIds.isNotEmpty) {
          _scheduleSync();
        }
      }
    }
  }

  /// A cached fallback is useful UI, but does not acknowledge remote catch-up.
  void retrySynchronization() {
    if (_disposed || _uid == null) return;
    _groupIds.addAll(_activeGroupIds);
    _outingIds.addAll(_activeOutingIds);
    _catchUp = true;
    _groupsDirty = _outingsDirty = _inboxDirty = true;
    // Force a real recovery even inside the resume/handshake coalescing window.
    _lastCatchUp = null;
    // Five delayed retries, then retain dirty state until resume, network
    // recovery, or another server invalidation. Never poll indefinitely.
    if (!_foreground || !_online || _syncRetry != null || _syncAttempt >= 5) {
      if (_syncAttempt >= 5) _syncAttempt = 6;
      return;
    }
    final seconds = 1 << _syncAttempt.clamp(0, 6);
    _syncAttempt++;
    _syncRetry = Timer(Duration(seconds: seconds), () {
      _syncRetry = null;
      _scheduleSync();
    });
    notifyListeners();
  }

  void sendsChanged() {
    if (_disposed) return;
    _retry?.cancel();
    _retry = null;
    if (_sending || _uid == null || !_foreground || !_online) return;
    if (!queue.hasPending) return;
    unawaited(_send());
  }

  Future<void> _send() async {
    final uid = _uid;
    final generation = _generation;
    _sending = true;
    notifyListeners();
    var retry = true;
    try {
      retry = await flushSends();
    } catch (error) {
      debugPrint(
        '[sync] Chat queue could not be drained: ${error.runtimeType}',
      );
    } finally {
      if (generation == _generation) {
        _sending = false;
        if (!_disposed &&
            retry &&
            (uid == _uid && generation == _generation) &&
            _foreground &&
            _online &&
            queue.hasPending) {
          final seconds = 1 << _attempt.clamp(0, 6);
          _attempt++;
          _retry = Timer(Duration(seconds: seconds), sendsChanged);
        } else {
          _attempt = 0;
          if (!_disposed &&
              (uid == _uid && generation == _generation) &&
              _foreground &&
              _online &&
              queue.hasPending) {
            scheduleMicrotask(sendsChanged);
          }
        }
        notifyListeners();
      }
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _retry?.cancel();
    _syncRetry?.cancel();
    unawaited(_networkSub.cancel());
    unawaited(_socketSub.cancel());
    unawaited(_dataSub.cancel());
    super.dispose();
  }
}
