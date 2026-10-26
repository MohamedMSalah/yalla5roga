import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_local_datasource.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_remote_datasource.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/domain/entities/outing_chat_read_result.dart';
import 'package:yalla_5roga/features/chat/domain/repositories/outing_chat_repository.dart';

class OutingChatRepositoryImpl implements OutingChatRepository {
  OutingChatRepositoryImpl({
    required this.remote,
    required this.local,
    required this.networkInfo,
  });

  final OutingChatRemoteDataSourceImpl remote;
  final OutingChatLocalDataSource local;
  final NetworkInfo networkInfo;

  final _memory = TtlCache<List<ChatMessage>>(ttl: CachePolicy.outingChat);

  @override
  List<ChatMessage> cachedMessages(String outingId) {
    return _memory.getStale(outingId) ?? local.getMessages(outingId);
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages(
    String outingId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final fresh = _memory.get(outingId);
      if (fresh != null) return Right(fresh);
    }

    final disk = local.getMessages(outingId);
    final result = await guardRemote(
      networkInfo,
      () => remote.getMessages(outingId),
      reason: 'loadOutingChat',
    );

    return await result.fold<Future<Either<Failure, List<ChatMessage>>>>(
      (failure) async {
        final fallback = disk.isNotEmpty
            ? disk
            : _memory.getStale(outingId) ?? const <ChatMessage>[];
        if (fallback.isNotEmpty) {
          _memory.set(outingId, fallback);
          return Right(fallback);
        }
        return Left(failure);
      },
      (remoteMessages) async {
        final merged = _merge(disk, remoteMessages);
        _memory.set(outingId, merged);
        await local.saveMessages(outingId, merged);
        return Right(merged);
      },
    );
  }

  @override
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String outingId,
    required String text,
    required String senderId,
    required String senderName,
    String? avatar,
  }) async {
    final now = DateTime.now();
    final pending = ChatMessage(
      id: 'local_${now.microsecondsSinceEpoch}',
      outingId: outingId,
      sender: senderName,
      text: text,
      time: _clock(now),
      isMine: true,
      avatar: avatar,
      senderId: senderId,
      sentAt: now,
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    await _upsert(outingId, pending);

    final result = await guardRemote(
      networkInfo,
      () => remote.sendMessage(
        outingId: outingId,
        text: text,
        senderId: senderId,
        senderName: senderName,
      ),
      reason: 'sendOutingChat',
    );

    return await result.fold<Future<Either<Failure, ChatMessage>>>(
      (failure) async {
        debugPrint('[OutingChat] send cached locally: ${failure.message}');
        return Right(pending);
      },
      (remoteMessage) async {
        final saved = remoteMessage.copyWith(
          outingId: outingId,
          isMine: true,
          senderId: senderId,
          sentAt: remoteMessage.sentAt ?? now,
          deliveryStatus: MessageDeliveryStatus.sent,
        );
        await _replace(outingId, pending.id, saved);
        return Right(saved);
      },
    );
  }

  @override
  Future<Either<Failure, OutingChatReadResult>> markRead(String outingId) {
    return guardRemote(
      networkInfo,
      () => remote.markRead(outingId),
      reason: 'markOutingChatRead',
    );
  }

  @override
  Future<void> clearCache() async {
    _memory.invalidate();
    await local.clear();
  }

  Future<void> _upsert(String outingId, ChatMessage message) {
    final next = _merge(cachedMessages(outingId), [message]);
    _memory.set(outingId, next);
    return local.saveMessages(outingId, next);
  }

  Future<void> _replace(
    String outingId,
    String pendingId,
    ChatMessage message,
  ) {
    final current = [
      for (final item in cachedMessages(outingId))
        if (item.id != pendingId) item,
    ];
    final next = _merge(current, [message]);
    _memory.set(outingId, next);
    return local.saveMessages(outingId, next);
  }

  List<ChatMessage> _merge(
    List<ChatMessage> localMessages,
    List<ChatMessage> remoteMessages,
  ) {
    final byId = <String, ChatMessage>{};
    for (final message in localMessages) {
      if (message.id.isEmpty) continue;
      byId[message.id] = message;
    }
    for (final message in remoteMessages) {
      if (message.id.isEmpty) continue;
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final aTime = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    return merged;
  }

  String _clock(DateTime at) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final period = at.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
