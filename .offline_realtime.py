exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit(f+'core/network/network_info.dart',
 ('  @override\n  Future<bool> get isConnected async {', '''  Stream<bool> get changes => _connectivity.onConnectivityChanged
      .map(_hasInterface)
      .distinct();

  static bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> get isConnected async {'''),
 ('    return results.any((result) => result != ConnectivityResult.none);','    return _hasInterface(results);'))
edit(f+'features/chat/data/datasources/chat_send_queue.dart',
 ('  List<ChatMessage> get messages {','''  bool get hasPending => messages.any(
    (message) => message.deliveryStatus == MessageDeliveryStatus.pending,
  );

  List<ChatMessage> get messages {'''),
 ('message.outingId != null)', 'message.outingId != null && message.sentAt != null)'))
edit(f+'features/chat/data/datasources/outing_chat_socket_client.dart',
 ('  final _connectionController', '''  final _dataController = StreamController<({String kind, String? id})>.broadcast();
  Stream<({String kind, String? id})> get dataChanges => _dataController.stream;

  int _session = 0;
  final _joined = <String>{};
  final _joining = <String>{};
  final _connectionController'''),
 ('    _connecting = true;', '    final session = _session;\n    _connecting = true;'),
 ('      final token = await tokenProvider();','      final token = await tokenProvider();\n      if (session != _session) return;'),
 ('tokenProvider(forceRefresh: true)','tokenProvider()'),
 ("      socket.onDisconnect((_) {", "      socket.onDisconnect((_) {\n        _joined.clear();\n        _joining.clear();"),
 ("      socket.on('outing:message', _onMessage);",'''      socket.on('data:changed', (dynamic raw) {
        final data = _asStringKeyedMap(raw);
        final kind = data?['kind'];
        final id = data?['id'];
        if (!_disposed && kind is String) {
          _dataController.add((kind: kind, id: id is String ? id : null));
        }
      });
      socket.on('outing:message', _onMessage);'''),
 ('      _connecting = false;','      if (session == _session) _connecting = false;'),
 ('''    if (socket == null || !socket.connected) return;

    final ack = await _emitWithAck(socket, 'outing:join', {
      'outingId': outingId,
    });
    if (ack['ok'] == true) return;''','''    if (socket == null || !socket.connected ||
        !_desiredOutingIds.contains(outingId) || _joined.contains(outingId) ||
        !_joining.add(outingId)) return;

    final ack = await _emitWithAck(socket, 'outing:join', {
      'outingId': outingId,
    });
    if (_socket != socket) return;
    _joining.remove(outingId);
    if (ack['ok'] == true) {
      if (_desiredOutingIds.contains(outingId)) {
        _joined.add(outingId);
      } else {
        await leaveOuting(outingId);
      }
      return;
    }'''),
 ('    _desiredOutingIds.remove(outingId);\n    final socket', '    _desiredOutingIds.remove(outingId);\n    _joined.remove(outingId);\n    final socket'),
 ('    _desiredOutingIds.clear();','''    _session++;
    _connecting = false;
    _authRetryScheduled = false;
    _desiredOutingIds.clear();
    _joined.clear();
    _joining.clear();'''),
 ('    await _arrivalController.close();','    await _arrivalController.close();\n    await _dataController.close();'),
 (' || _desiredOutingIds.isEmpty',''),
 ('    _authRetryScheduled = true;','    _authRetryScheduled = true;\n    final session = _session;'),
 ('      if (_disposed) return;\n      await _disposeSocket();','      if (_disposed || session != _session) return;\n      await _disposeSocket();'),
 ('    _connectCompleter = null;','''    if (!(_connectCompleter?.isCompleted ?? true)) _connectCompleter?.complete();
    _connectCompleter = null;'''))
edit(f+'features/chat/presentation/providers/outing_chat_provider.dart',
 ('    OutingChatSocketClient? socketClient,','''    OutingChatSocketClient? socketClient,
    Stream<ChatMessage>? sendUpdates,
    this.onQueued,
    this.persistLiveMessage,'''),
 ('    final socket = _socket;', '''    _sendSub = sendUpdates?.listen(_applyLiveMessage);
    final socket = _socket;'''),
 ('  final OutingChatSocketClient? _socket;', '''  final OutingChatSocketClient? _socket;
  final VoidCallback? onQueued;
  final Future<void> Function(ChatMessage)? persistLiveMessage;
  StreamSubscription<ChatMessage>? _sendSub;'''),
 ('''    await load(outingId, forceRefresh: forceRefresh, userId: _currentUserId);
    if (!_activeOutings.containsKey(outingId)) return;
    if (subscriptions == 1) await _socket?.joinOuting(outingId);''','''    if (subscriptions == 1) unawaited(_socket?.joinOuting(outingId));
    final generation = _generation;
    await load(outingId, forceRefresh: forceRefresh, userId: _currentUserId);
    if (generation != _generation || !_activeOutings.containsKey(outingId)) return;'''),
 ('''    final byId = {
      for (final item in messagesFor(outingId)) item.id: item,
      for (final item in _withMine(items, _currentUserId)) item.id: item,
    };
    _messages[outingId] = byId.values.toList()
      ..sort((a, b) {
        final byTime = (a.sentAt?.microsecondsSinceEpoch ?? 0).compareTo(
          b.sentAt?.microsecondsSinceEpoch ?? 0,
        );
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });''','''    var merged = messagesFor(outingId);
    for (final item in _withMine(items, _currentUserId)) {
      merged = upsertOutingChatMessage(merged, item);
    }
    _messages[outingId] = merged;'''),
 ('      (failure) {\n        _errorMessage = AppErrorFeedback.messageOf(failure);','''      (failure) {
        if (failure.statusCode == 403 || failure.statusCode == 404) {
          _messages.remove(outingId);
        }
        _errorMessage = AppErrorFeedback.messageOf(failure);'''),
 ('    _currentUserId = senderId;','    final generation = _generation;\n    _currentUserId = senderId;'),
 ('    var ok = false;','    if (generation != _generation) return false;\n    var ok = false;'),
 ('        ok = true;', '        ok = true;\n        if (message.deliveryStatus == MessageDeliveryStatus.pending) onQueued?.call();'),
 ('    final result = await repository.markRead(outingId);','''    final generation = _generation;
    final result = await repository.markRead(outingId);
    if (generation != _generation) return;'''),
 ('''    final active = _activeOutings.keys.toList();
''',''),
 ('''    unawaited(() async {
      for (final outingId in active) {
        await _socket?.leaveOuting(outingId);
      }
      await _socket?.disconnect();
    }());''','    unawaited(_socket?.disconnect());'),
 ('    _messageSub?.cancel();','    _messageSub?.cancel();\n    _sendSub?.cancel();'),
 ('    final enriched = message.copyWith(', '''    unawaited(persistLiveMessage?.call(message));
    _applyLiveMessage(message);
  }

  void _applyLiveMessage(ChatMessage message) {
    final outingId = message.outingId;
    if (outingId == null || !_activeOutings.containsKey(outingId)) return;
    final enriched = message.copyWith('''),
 ('    _messages[outingId] = upsertOutingChatMessage(\n      messagesFor(outingId),\n      enriched,\n    );','''    final current = messagesFor(outingId);
    if (current.any((item) => item.id == enriched.id &&
        item.deliveryStatus == enriched.deliveryStatus &&
        item.text == enriched.text && item.sender == enriched.sender)) return;
    _messages[outingId] = upsertOutingChatMessage(current, enriched);'''))
