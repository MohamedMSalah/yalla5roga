exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit(f+'features/chat/data/datasources/outing_chat_socket_client.dart',
 ('  final _joining = <String>{};','  final _joining = <String, Future<void>>{};'),
 ('''    if (socket == null || !socket.connected ||
        !_desiredOutingIds.contains(outingId) || _joined.contains(outingId) ||
        !_joining.add(outingId)) return;

    final ack''','''    if (socket == null || !socket.connected ||
        !_desiredOutingIds.contains(outingId) || _joined.contains(outingId)) return;
    return _joining.putIfAbsent(outingId, () {
      final join = _join(socket, outingId);
      unawaited(join.whenComplete(() {
        if (identical(_joining[outingId], join)) _joining.remove(outingId);
      }));
      return join;
    });
  }

  Future<void> _join(io.Socket socket, String outingId) async {
    final connection = socket.id;
    final ack'''),
 ('''    if (_socket != socket) return;
    _joining.remove(outingId);''','''    if (_socket != socket || socket.id != connection) return;'''),
 ('''    final ids = _desiredOutingIds.toList();
    for (final outingId in ids) {
      await joinOuting(outingId);
    }''','''    await Future.wait(_desiredOutingIds.toList().map(joinOuting));'''))
edit(f+'features/chat/presentation/providers/outing_chat_provider.dart',
 ('    _connectionSub = socket.connectionChanges.listen(_onConnectionChange);\n',''),
 ('  StreamSubscription<bool>? _connectionSub;\n  Timer? _recoveryDebounce;\n',''),
 ('''  /// Foreground / network regain: rejoin rooms and REST-fill gaps.
  Future<void> recoverAfterResume({String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }
    if (_activeOutings.isEmpty && (_socket?.joinedOutingIds.isEmpty ?? true)) {
      return;
    }
    await _socket?.recover();
    await recoverActiveChats();
  }

''',''),
 ('    _recoveryDebounce?.cancel();\n    _recoveryDebounce = null;\n',''),
 ('    _recoveryDebounce?.cancel();\n',''),
 ('    _connectionSub?.cancel();\n',''),
 ('''  void _onConnectionChange(bool connected) {
    if (!connected) return;
    // Debounce: connect + resume can fire close together.
    _recoveryDebounce?.cancel();
    _recoveryDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(recoverActiveChats());
    });
  }

''',''),
 ('''  Future<void> recoverActiveChats() async {
    _recoveryDebounce?.cancel();
    _recoveryDebounce = null;
    for (final outingId in _activeOutings.keys.toList()) {
      await load(outingId, forceRefresh: true, userId: _currentUserId);
    }
  }''','''  Future<void> recoverActiveChats() async {
    if (_activeOutings.isEmpty) return;
    if (_socket?.isConnected == true) await _socket?.recover();
    for (final outingId in _activeOutings.keys.toList()) {
      await load(outingId, forceRefresh: true, userId: _currentUserId);
      if (_activeOutings.containsKey(outingId) && _errorMessage == null) {
        await markRead(outingId);
      }
    }
  }'''))
edit(f+'core/network/app_sync_provider.dart',
 ('  bool _observedSocket = false;', '  bool _needsSocketCatchUp = true;'),
 ('    _observedSocket = false;', '    _needsSocketCatchUp = true;'),
 ('''    if (!connected) return;
    if (_observedSocket || _lastCatchUp == null && !_working) _catchUp = true;
    _observedSocket = true;''','''    if (!connected) {
      _needsSocketCatchUp = true;
      return;
    }
    if (_needsSocketCatchUp) _catchUp = true;'''),
 ('''    final full = _catchUp && (lastCatchUp == null ||
        DateTime.now().difference(lastCatchUp) > const Duration(seconds: 2));''','''    final full = _catchUp && (lastCatchUp == null ||
        socket.isConnected && _needsSocketCatchUp ||
        DateTime.now().difference(lastCatchUp) > const Duration(seconds: 2));
    if (full && socket.isConnected) _needsSocketCatchUp = false;'''))
edit(f+'features/auth/presentation/providers/auth_provider.dart',
 ('''      (user) {
        _user = user;
        notifyListeners();
      },
    );
  }

  Future<bool> updateProfile''','''      (user) {
        if (_user == user) return;
        _user = user;
        notifyListeners();
      },
    );
  }

  Future<bool> updateProfile'''))
