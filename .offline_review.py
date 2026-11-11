exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit('flutter/test/group_account_linking_test.dart',
 ("'session restore waits for invitation sync before shell group loading'", "'session restores cached profile before online invitation sync'"),
 ('''      var completed = false;
      final restoration = auth.restoreSession().then((_) => completed = true);
      await started.future;
      expect(completed, isFalse);
      release.complete();
      await restoration;
      expect(completed, isTrue);
      expect(auth.user?.id, 'B');''','''      await auth.restoreSession();
      expect(auth.user?.id, 'B');
      expect(auth.user?.hasPassword, isFalse);
      expect(started.isCompleted, isFalse);

      final refresh = auth.refreshProfile();
      await started.future;
      expect(auth.user?.hasPassword, isFalse);
      release.complete();
      await refresh;
      expect(auth.user?.hasPassword, isTrue);'''))
edit(f+'core/network/api_client.dart',
 ('''      final data = store?.read<T>(key);''','''      if (store?.userId() != uid || store?.generation != generation) return null;
      final data = store?.read<T>(key);'''))
edit(f+'core/cache/cached_remote.dart',
 ('''if (allowStaleOnError && (failure is NetworkFailure || failure.statusCode != null && failure.statusCode! >= 500))''','''if (allowStaleOnError && (!offlineRead ||
              failure is NetworkFailure || (failure.statusCode ?? 0) >= 500))'''))
edit(f+'features/outings/presentation/providers/outings_provider.dart',
 ('''  void _applySnapshot(OutingSnapshot snapshot, {bool reschedule = true}) {
    // A refresh started before DELETE may still contain the old outing.
    for (final id in _deletedOutingIds)''','''  void _applySnapshot(OutingSnapshot snapshot, {bool reschedule = true}) {
    // An overlapping detail request may still contain a revoked or deleted outing.
    for (final id in {..._deletedOutingIds, ..._unavailableOutings})'''),
 ('''          a[i].going != b[i].going) {''','''          a[i].going != b[i].going ||
          a[i].meta != b[i].meta ||
          a[i].date != b[i].date ||
          a[i].time != b[i].time ||
          a[i].groupId != b[i].groupId ||
          a[i].location?.placeId != b[i].location?.placeId ||
          a[i].occasion != b[i].occasion ||
          a[i].type != b[i].type ||
          a[i].createdById != b[i].createdById ||
          a[i].suggestedBy != b[i].suggestedBy ||
          a[i].voteDeadlineHours != b[i].voteDeadlineHours ||
          !listEquals(a[i].guestIds, b[i].guestIds) ||
          !listEquals(a[i].guestPhones, b[i].guestPhones) ||
          a[i].votePlaces.length != b[i].votePlaces.length) {'''),
 ('''    }
    return true;
  }

  String specialEventImage''','''      for (var index = 0; index < a[i].votePlaces.length; index++) {
        if (!mapEquals(a[i].votePlaces[index].toJson(), b[i].votePlaces[index].toJson())) return false;
      }
    }
    return true;
  }

  String specialEventImage'''))
# Ignore missed detail cache only after an authoritative denial, including its subresources.
edit(f+'core/cache/offline_snapshots.dart',
 ('''  Future<void> clear(String uid) async {''','''  Future<void> removeResource(String key) async {
    final path = key.indexOf(':/api/');
    if (path == -1) return;
    final resource = key.substring(0, path + 1) +
        key.substring(path + 1).split('/').take(4).join('/');
    await Future.wait(_prefs.getKeys().where((entry) =>
      entry == resource || entry.startsWith('$resource/'),
    ).map(remove));
  }

  Future<void> clear(String uid) async {'''))
edit(f+'core/network/api_client.dart',
 ('''          await store.remove(key);''','''          if (status == 403 || status == 404 || status == 410) {
            // A detail denial invalidates subresources. A denied subresource
            // (such as attendance for a pending guest) can have narrower access.
            if (path.split('/').length == 4) {
              await store.removeResource(key);
            } else {
              await store.remove(key);
            }
          } else {
            await store.remove(key);
          }'''))
edit(f+'features/chat/data/datasources/outing_chat_socket_client.dart',
 ('  var _forceTokenRefresh = false;', '  var _forceTokenRefresh = false;\n  int _authAttempts = 0;'),
 ('            .setReconnectionAttempts(12)\n',''),
 ('''      if (token == null || token.isEmpty) {
        debugPrint('[OutingChatSocket] no Firebase ID token; skip connect');''','''      if (token == null || token.isEmpty) {
        _scheduleAuthRetryIfNeeded('unauthorized');'''),
 ('''        _authRetryScheduled = false;
        _emitConnection(true);''','''        _authRetryScheduled = false;
        _authAttempts = 0;
        _emitConnection(true);'''),
 ('''      if (session == _session) _emitConnection(false);''','''      if (session == _session) {
        _emitConnection(false);
        _scheduleAuthRetryIfNeeded('unauthorized');
      }'''),
 ('    _forceTokenRefresh = false;\n    _desiredOutingIds.clear();','    _forceTokenRefresh = false;\n    _authAttempts = 0;\n    _desiredOutingIds.clear();'),
 ("    unawaited(() async {\n      await Future<void>.delayed(const Duration(milliseconds: 400));",'''    final seconds = 1 << _authAttempts.clamp(0, 6);
    _authAttempts++;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: seconds));'''))
# Mark user profile changes made through the authenticated sync endpoint.
edit('backend/src/controllers/users/user.controller.ts',
 ('      res.status(200).json({', '''      if (["name", "phone", "image_url", "phoneVerificationToken"].some((key) => req.body[key] !== undefined)) {
        emitDataChange({ kind: "profile" }, [req.user.uid]);
      }
      res.status(200).json({'''))
