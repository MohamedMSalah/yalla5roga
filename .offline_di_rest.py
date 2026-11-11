exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit(f+'features/shell/presentation/pages/main_shell.dart',
 ("import 'package:yalla_5roga/core/monitoring/startup_trace.dart';","import 'package:yalla_5roga/core/monitoring/startup_trace.dart';\nimport 'package:yalla_5roga/core/network/app_sync_provider.dart';"),
 ("import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';\n",''),
 ("import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';\n",''),
 ('  Timer? _resumeDebounce;\n',''),
 ('    _resumeDebounce?.cancel();\n',''),
 ('''      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(const Duration(seconds: 2), () {
        if (mounted) _refreshUnread();
      });
''',''),
 ('    await context.read<OutingsProvider>().load();','    final synchronization = context.read<AppSyncProvider>().start();'),
 ('''    await context.read<GroupsProvider>().refresh();
    if (!mounted) return;
    unawaited(context.read<NotificationsProvider>().refresh());''','''    await synchronization;
    if (!mounted) return;'''),
 ('''  void _refreshUnread() {
    // TTL-aware â€” do not force network on every brief resume.
    context.read<NotificationsProvider>().refresh();
    context.read<GroupsProvider>().refresh();
  }

''',''))
edit(f+'features/auth/data/repositories/auth_repository_impl.dart',
 ('      return Right(await local.getCachedUser());','''      final cached = await local.getCachedUser();
      if (firebaseAuth.currentUser?.uid != cached.id) {
        return const Left(CacheFailure('Cached profile belongs to another session'));
      }
      return Right(cached);'''),
 ('      final model = await remote.syncUser();\n      final token', '''      final uid = firebaseAuth.currentUser?.uid;
      if (uid == null) return const Left(AuthFailure());
      final model = await remote.syncUser();
      if (firebaseAuth.currentUser?.uid != uid || model.id != uid) {
        return const Left(AuthFailure());
      }
      final token'''))
edit(f+'features/auth/presentation/providers/auth_provider.dart',
 ('''    } else {
      // Claim verified-phone invitations before MainShell reads its groups.
      await refreshProfile();
      unawaited(repository.debugPrintSwaggerIdToken());
    }
    notifyListeners();''','''    }
    notifyListeners();'''),
 ('''    if (_user == null) return;
    final result = await repository.refreshProfile();''','''    final uid = _user?.id;
    if (uid == null) return;
    final result = await repository.refreshProfile();
    if (_user?.id != uid) return;'''))
edit(f+'features/groups/presentation/providers/groups_provider.dart',
 ("import 'package:flutter/foundation.dart';","import 'package:flutter/foundation.dart';\nimport 'package:yalla_5roga/core/cache/offline_snapshots.dart';"),
 ('  var _epoch = 0;', '''  var _epoch = 0;
  final _openGroups = <String, int>{};
  Iterable<String> get openGroupIds => _openGroups.keys;

  void openGroup(String id) => _openGroups.update(id, (count) => count + 1, ifAbsent: () => 1);

  void closeGroup(String id) {
    final count = _openGroups[id] ?? 0;
    if (count <= 1) {
      _openGroups.remove(id);
    } else {
      _openGroups[id] = count - 1;
    }
  }'''),
 ('''    return result.fold((_) => allowStale ? existing : null, (group) {''','''    return result.fold((failure) {
      if (failure.statusCode == 403 || failure.statusCode == 404) {
        _groups.removeWhere((item) => item.id == groupId);
        notifyListeners();
        return null;
      }
      return allowStale ? existing : null;
    }, (group) {'''),
 ('''    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);''','''    if (OfflineSnapshots.cacheOnly && result.isLeft()) return;
    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);'''),
 ('''        _groups = List.of(groups);''','''        final existing = {for (final group in _groups) group.id: group};
        _groups = [
          for (final group in groups)
            if (existing[group.id] case final previous?)
              group.copyWith(members: previous.members, pendingMembers: previous.pendingMembers)
            else
              group,
        ];'''),
 ('    repository.clearCache();','    repository.clearCache();\n    _openGroups.clear();'))
edit(f+'features/outings/presentation/providers/outings_provider.dart',
 ("import 'package:flutter/foundation.dart';","import 'package:flutter/foundation.dart';\nimport 'package:yalla_5roga/core/cache/offline_snapshots.dart';"),
 ('  int get featuredIndex', '''  int _sessionEpoch = 0;
  final _openOutings = <String, int>{};
  Iterable<String> get openOutingIds => _openOutings.keys;
  bool containsOuting(String id) => findById(id) != null;

  void openOuting(String id) => _openOutings.update(id, (count) => count + 1, ifAbsent: () => 1);

  void closeOuting(String id) {
    final count = _openOutings[id] ?? 0;
    if (count <= 1) {
      _openOutings.remove(id);
    } else {
      _openOutings[id] = count - 1;
    }
  }

  int get featuredIndex'''),
 ('''    final result = await repository.load(forceRefresh: forceRefresh);
    result.fold((failure) {''','''    final epoch = _sessionEpoch;
    final result = await repository.load(forceRefresh: forceRefresh);
    if (epoch != _sessionEpoch || OfflineSnapshots.cacheOnly && result.isLeft()) return;
    var changed = !_hasLoaded;
    result.fold((failure) {
      changed = changed || _errorMessage != AppErrorFeedback.messageOf(failure);'''),
 ('''    }, _applySnapshot);
    _hasLoaded = true;
    notifyListeners();''','''    }, (snapshot) {
      changed = changed || _errorMessage != null || _snapshotDiffers(snapshot);
      if (changed) _applySnapshot(snapshot);
    });
    _hasLoaded = true;
    if (changed) notifyListeners();'''),
 ('  void clear() {','  void clear() {\n    _sessionEpoch++;\n    _openOutings.clear();'),
 ('''    final result = await repository.refreshLifecycle(
      outingId: outingId,
      forceRefresh: forceRefresh,
    );''','''    final epoch = _sessionEpoch;
    final result = await repository.refreshLifecycle(
      outingId: outingId,
      forceRefresh: forceRefresh,
    );
    if (epoch != _sessionEpoch || OfflineSnapshots.cacheOnly && result.isLeft()) return false;'''))
for filename, cls in [('group_info_page.dart','_GroupInfoPageState'),('group_details_page.dart','_GroupDetailsPageState')]:
 p=Path(f+'features/groups/presentation/pages/'+filename)
 s=p.read_text(encoding='utf-8')
 i=s.index('  @override\n  void initState()',s.index('class '+cls))
 s=s[:i]+'''  GroupsProvider? _openGroupProvider;

  @override
  void dispose() {
    _openGroupProvider?.closeGroup(widget.groupId);
    super.dispose();
  }

'''+s[i:]
 s=s.replace('    super.initState();','    super.initState();\n    _openGroupProvider = context.read<GroupsProvider>()..openGroup(widget.groupId);',1)
 p.write_text(s,encoding='utf-8')
edit(f+'features/outings/presentation/pages/event_page.dart',
 ('  var _loadingDetails = true;','  var _loadingDetails = true;\n  OutingsProvider? _openOutingProvider;'),
 ('    super.initState();','    super.initState();\n    _openOutingProvider = context.read<OutingsProvider>()..openOuting(widget.event.id);'),
 ('    FlyingItemAnimator.cancel();','    _openOutingProvider?.closeOuting(widget.event.id);\n    FlyingItemAnimator.cancel();'))
