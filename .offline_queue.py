exec(open('.offline_edits.py',encoding='utf-8').read().split("edit(f+")[0])
edit(f+'features/chat/domain/entities/chat_message.dart',
 ('{ sent, delivered, seen }','{ pending, failed, sent, delivered, seen }'))
edit(f+'features/chat/domain/outing_chat_message_merge.dart',
 ('  final without', '''  if (!isServer && items.any((item) =>
      !isLocalPendingMessageId(item.id) && _sameOptimistic(message, item))) {
    return items;
  }
  final without'''))
edit(f+'features/chat/data/repositories/outing_chat_repository_impl.dart',
 ("import 'package:dartz/dartz.dart';","""import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/features/chat/data/datasources/chat_send_queue.dart';
import 'package:yalla_5roga/features/chat/domain/outing_chat_message_merge.dart';"""),
 ('    RequestDeduper? deduper,','    RequestDeduper? deduper,\n    this.sendQueue,'),
 ('  final RequestDeduper _deduper;', '''  final RequestDeduper _deduper;
  final ChatSendQueue? sendQueue;

  Future<bool> flushSends() async {
    if (!await networkInfo.isConnected) return true;
    return await sendQueue?.flush((pending) async {
      final outingId = pending.outingId!;
      final generation = _generation;
      final saved = await remote.sendMessage(
        outingId: outingId,
        text: pending.text,
        senderId: pending.senderId!,
        senderName: pending.sender,
        clientMessageId: pending.clientMessageId!,
      );
      if (generation == _generation) await _upsert(outingId, saved);
      return saved;
    }) ?? false;
  }

  Future<void> persistLiveMessage(ChatMessage message) =>
      _upsert(message.outingId!, message);'''),
 ('    return _memory.getStale(outingId) ?? local.getMessages(outingId);','''    return _merge(
      _memory.getStale(outingId) ?? local.getMessages(outingId),
      sendQueue?.messages.where((item) => item.outingId == outingId).toList() ?? const [],
    );'''),
 ("        query: {'force': forceRefresh},\n",''),
 ('''            final fallback = disk.isNotEmpty
                ? disk
                : _memory.getStale(outingId) ?? const <ChatMessage>[];''','''            if (generation != _generation) return const Right([]);
            if (failure.statusCode == 403 || failure.statusCode == 404) {
              _memory.invalidate(outingId);
              await local.saveMessages(outingId, []);
              return Left(failure);
            }
            final fallback = cachedMessages(outingId);'''),
 ('            final merged = _merge(disk, page.messages);','            final merged = _merge(cachedMessages(outingId), page.messages);'),
 ('        final disk = local.getMessages(outingId);\n',''),
 ('''    await _upsert(outingId, pending);

    final result''','''    final queue = sendQueue;
    if (queue != null) {
      final queued = pending.copyWith(deliveryStatus: MessageDeliveryStatus.pending);
      try {
        await queue.add(queued);
        return Right(queued);
      } on AppException catch (error) {
        return Left(ExceptionMapper.toFailure(error));
      }
    }

    final generation = _generation;
    await _upsert(outingId, pending);
    final result'''),
 ('''    return await result.fold<Future<Either<Failure, ChatMessage>>>(''','''    if (generation != _generation) return const Left(AuthFailure());
    return await result.fold<Future<Either<Failure, ChatMessage>>>('''),
 ('''    final byId = <String, ChatMessage>{};''','''    if (localMessages.any((item) => isLocalPendingMessageId(item.id)) ||
        remoteMessages.any((item) => isLocalPendingMessageId(item.id))) {
      final byClientId = {
        for (final item in [...localMessages, ...remoteMessages])
          if (!isLocalPendingMessageId(item.id) && item.clientMessageId != null)
            item.clientMessageId,
      };
      localMessages = localMessages.where((item) =>
          !isLocalPendingMessageId(item.id) || !byClientId.contains(item.clientMessageId)).toList();
      remoteMessages = remoteMessages.where((item) =>
          !isLocalPendingMessageId(item.id) || !byClientId.contains(item.clientMessageId)).toList();
    }
    final byId = <String, ChatMessage>{};'''))
edit(f+'features/chat/data/datasources/outing_chat_local_datasource.dart',
 ('OutingChatLocalDataSourceImpl(this._prefs) {','''OutingChatLocalDataSourceImpl(this._prefs, {String? Function()? userId, String? origin})
    : _userId = userId, _origin = origin {
    _uid = _userId?.call();'''),
 ('  final SharedPreferences _prefs;', '''  final SharedPreferences _prefs;
  final String? Function()? _userId;
  final String? _origin;
  String? _uid;
  String? get _key => _userId == null
      ? AppConstants.outingChatMessagesKey
      : _uid == null ? null : '${AppConstants.outingChatMessagesKey}:$_origin:$_uid';

  void _switchAccount() {
    final uid = _userId?.call();
    if (_uid == uid) return;
    _persistTimer?.cancel();
    _byOuting = {};
    _uid = uid;
    _load();
  }'''),
 ('final raw = _prefs.getString(AppConstants.outingChatMessagesKey);', 'final key = _key;\n    final raw = key == null ? null : _prefs.getString(key);'),
 ('  Future<void> _persist() {\n    return _prefs.setString(\n      AppConstants.outingChatMessagesKey,','  Future<void> _persist() async {\n    final key = _key;\n    if (key == null) return;\n    await _prefs.setString(\n      key,'),
 ('for (final item in entry.value) item.toJson()', "for (final item in entry.value) if (!item.id.startsWith('local_')) item.toJson()"),
 ('    return List.unmodifiable(_byOuting','    _switchAccount();\n    return List.unmodifiable(_byOuting'),
 ('    final retained =','    _switchAccount();\n    final retained ='),
 ('    await _prefs.remove(AppConstants.outingChatMessagesKey);','    final key = _key;\n    if (key != null) await _prefs.remove(key);\n    await _prefs.remove(AppConstants.outingChatMessagesKey);'))
