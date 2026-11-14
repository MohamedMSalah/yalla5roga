import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/features/chat/data/datasources/chat_send_queue.dart';
import 'package:yalla_5roga/features/chat/domain/outing_chat_message_merge.dart';

import 'dart:math';

import 'package:yalla_5roga/core/cache/cache_policy.dart';
import 'package:yalla_5roga/core/cache/ttl_cache.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/core/network/remote_guard.dart';
import 'package:yalla_5roga/core/network/request_deduper.dart';
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
    RequestDeduper? deduper,
    this.sendQueue,
  }) : _deduper = deduper ?? RequestDeduper();

  final OutingChatRemoteDataSourceImpl remote;
  final OutingChatLocalDataSource local;
  final NetworkInfo networkInfo;
  final RequestDeduper _deduper;
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
        }) ??
        false;
  }

  Future<void> persistLiveMessage(ChatMessage message) =>
      _upsert(message.outingId!, message);

  final _memory = TtlCache<List<ChatMessage>>(ttl: CachePolicy.outingChat);

  final _olderCursor = <String, String?>{};
  int _generation = 0;

  @override
  Future<Either<Failure, ChatMessage>> getMessage(
    String outingId,
    String messageId,
  ) => guardRemote(networkInfo, () async {
    final page = await remote.getMessages(outingId, messageId: messageId);
    final message = page.messages.singleOrNull;
    if (message == null || message.id != messageId) {
      throw const ServerException('Message not found', 'NOT_FOUND', 404);
    }
    return message;
  }, reason: 'getNotificationChatMessage');

  @override
  bool hasOlderMessages(String outingId) => _olderCursor[outingId] != null;

  @override
  Future<Either<Failure, List<ChatMessage>>> getOlderMessages(
    String outingId,
  ) async {
    final before = _olderCursor[outingId];
    if (before == null) return const Right([]);
    final generation = _generation;
    final result = await guardRemote(
      networkInfo,
      () => remote.getMessages(outingId, before: before),
      reason: 'loadOlderOutingChat',
    );
    return result.map((page) {
      if (generation != _generation) return const [];
      _olderCursor[outingId] = page.nextCursor;
      return page.messages;
    });
  }

  @override
  List<ChatMessage> cachedMessages(String outingId) {
    return _merge(
      _memory.getStale(outingId) ?? local.getMessages(outingId),
      sendQueue?.messages.where((item) => item.outingId == outingId).toList() ??
          const [],
    );
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

    return _deduper.run(
      RequestDeduper.keyFor(method: 'GET', path: 'chat:$outingId'),
      () async {
        if (!forceRefresh) {
          final fresh = _memory.get(outingId);
          if (fresh != null) return Right(fresh);
        }

        final generation = _generation;
        final result = await guardRemote(
          networkInfo,
          () => remote.getMessages(outingId),
          reason: 'loadOutingChat',
        );

        return await result.fold<Future<Either<Failure, List<ChatMessage>>>>(
          (failure) async {
            if (generation != _generation) return const Right([]);
            if (failure.statusCode == 401 ||
                failure.statusCode == 403 ||
                failure.statusCode == 404) {
              _memory.invalidate(outingId);
              await local.saveMessages(outingId, []);
              return Left(failure);
            }
            final fallback = cachedMessages(outingId);
            if (fallback.isNotEmpty) {
              _memory.set(outingId, fallback);
              return Right(fallback);
            }
            return Left(failure);
          },
          (page) async {
            if (generation != _generation) return const Right([]);
            // Recovery replaces a bounded authoritative window, including edited
            // messages and tombstones missed while disconnected. Older history
            // remains available through its normal cursor.
            final canonical = [...page.messages];
            var cursor = page.nextCursor;
            final retain = cachedMessages(outingId)
                .where((m) => !m.id.startsWith('local_'))
                .length
                .clamp(40, 100);
            if (forceRefresh) {
              while (cursor != null && canonical.length < retain) {
                final older = await guardRemote(
                  networkInfo,
                  () => remote.getMessages(outingId, before: cursor),
                  reason: 'reconcileOutingChat',
                );
                if (generation != _generation) return const Right([]);
                final failure = older.fold<Failure?>((f) => f, (_) => null);
                if (failure != null) return Left(failure);
                final next = older.getOrElse(
                  () => (messages: <ChatMessage>[], nextCursor: null),
                );
                canonical.insertAll(0, next.messages);
                if (next.nextCursor == cursor) break;
                cursor = next.nextCursor;
              }
              _olderCursor[outingId] = cursor;
            } else {
              _olderCursor.putIfAbsent(outingId, () => cursor);
            }
            final queued =
                sendQueue?.messages
                    .where((m) => m.outingId == outingId)
                    .toList() ??
                <ChatMessage>[];
            final merged = forceRefresh
                ? _merge(canonical, queued)
                : _merge(cachedMessages(outingId), canonical);
            _memory.set(outingId, merged);
            await local.saveMessages(outingId, merged);
            return Right(merged);
          },
        );
      },
      feature: 'chat',
      source: 'OutingChatRepositoryImpl',
      operation: 'getMessages',
      endpoint: 'chat:$outingId',
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
    final clientMessageId = _newMessageId();
    final pending = ChatMessage(
      id: 'local_$clientMessageId',
      clientMessageId: clientMessageId,
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
    final queue = sendQueue;
    if (queue != null) {
      final queued = pending.copyWith(
        deliveryStatus: MessageDeliveryStatus.pending,
      );
      try {
        await queue.add(queued);
        return Right(queued);
      } on AppException catch (error) {
        return Left(ExceptionMapper.toFailure(error));
      } catch (_) {
        return const Left(CacheFailure('Could not save the pending message'));
      }
    }

    final generation = _generation;
    await _upsert(outingId, pending);
    final result = await guardRemote(
      networkInfo,
      () => remote.sendMessage(
        outingId: outingId,
        text: text,
        senderId: senderId,
        senderName: senderName,
        clientMessageId: clientMessageId,
      ),
      reason: 'sendOutingChat',
    );

    if (generation != _generation) return const Left(AuthFailure());
    return await result.fold<Future<Either<Failure, ChatMessage>>>(
      (failure) async {
        await _replace(outingId, pending.id);
        return Left(failure);
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
  Future<Either<Failure, ChatMessage>> mutateMessage(
    String outingId,
    String messageId, {
    String? text,
  }) async {
    final generation = _generation;
    final result = await guardRemote(
      networkInfo,
      () => remote.mutateMessage(outingId, messageId, text: text),
      reason: 'mutateOutingChat',
    );
    if (generation != _generation) return const Left(AuthFailure());
    return await result.fold((failure) async => Left(failure), (message) async {
      await _upsert(outingId, message);
      return Right(message);
    });
  }

  @override
  Future<Either<Failure, ChatMessage>> retryMessage(ChatMessage message) async {
    final queue = sendQueue;
    if (queue == null || message.clientMessageId == null) {
      return const Left(CacheFailure('Pending message unavailable'));
    }
    try {
      final pending = message.copyWith(
        deliveryStatus: MessageDeliveryStatus.pending,
      );
      await queue.add(pending);
      return Right(pending);
    } on AppException catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    } catch (_) {
      return const Left(CacheFailure('Could not save the pending message'));
    }
  }

  @override
  Future<void> clearCache() async {
    _generation++;
    _olderCursor.clear();
    _memory.invalidate();
    _deduper.clear();
    await local.clear();
  }

  Future<void> _upsert(String outingId, ChatMessage message) {
    final next = _merge(cachedMessages(outingId), [message]);
    _memory.set(outingId, next);
    return local.saveMessages(outingId, next);
  }

  Future<void> _replace(
    String outingId,
    String pendingId, [
    ChatMessage? message,
  ]) {
    final current = [
      for (final item in cachedMessages(outingId))
        if (item.id != pendingId) item,
    ];
    final next = _merge(current, [?message]);
    _memory.set(outingId, next);
    return local.saveMessages(outingId, next);
  }

  List<ChatMessage> _merge(
    List<ChatMessage> localMessages,
    List<ChatMessage> remoteMessages,
  ) {
    if (localMessages.any((item) => isLocalPendingMessageId(item.id)) ||
        remoteMessages.any((item) => isLocalPendingMessageId(item.id))) {
      final byClientId = {
        for (final item in [...localMessages, ...remoteMessages])
          if (!isLocalPendingMessageId(item.id) && item.clientMessageId != null)
            item.clientMessageId,
      };
      localMessages = localMessages
          .where(
            (item) =>
                !isLocalPendingMessageId(item.id) ||
                !byClientId.contains(item.clientMessageId),
          )
          .toList();
      remoteMessages = remoteMessages
          .where(
            (item) =>
                !isLocalPendingMessageId(item.id) ||
                !byClientId.contains(item.clientMessageId),
          )
          .toList();
    }
    final byId = <String, ChatMessage>{};
    for (final message in localMessages) {
      if (message.id.isEmpty) continue;
      byId[message.id] = message;
    }
    for (final message in remoteMessages) {
      if (message.id.isEmpty) continue;
      if (byId[message.id]?.text.isEmpty == true && message.text.isNotEmpty) {
        continue;
      }
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final aTime = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byTime = aTime.compareTo(bTime);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
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

String _newMessageId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
