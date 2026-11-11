import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/features/notifications/data/datasources/fcm_token_remote_datasource.dart';
import 'package:yalla_5roga/features/notifications/data/services/fcm_messaging_service.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_authorization_status.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/push_messaging_repository.dart';

class PushMessagingRepositoryImpl implements PushMessagingRepository {
  PushMessagingRepositoryImpl({
    required this.messaging,
    this.tokenRemote,
  });

  final FcmMessagingService messaging;
  final FcmTokenRemoteDataSource? tokenRemote;

  @override
  Future<void> initialize({
    required void Function(PushNotificationPayload) onOpened,
  }) async {
    await messaging.initialize(onOpened: onOpened);
    messaging.tokenStream.listen(_syncTokenQuietly);
    final current = messaging.token;
    if (current != null) {
      unawaited(_syncTokenQuietly(current));
    }
  }

  @override
  String? get token => messaging.token;

  @override
  Stream<String?> get tokenStream => messaging.tokenStream;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    final status = await messaging.requestPermission();
    return switch (status) {
      AuthorizationStatus.authorized => PushAuthorizationStatus.authorized,
      AuthorizationStatus.provisional => PushAuthorizationStatus.provisional,
      AuthorizationStatus.denied => PushAuthorizationStatus.denied,
      _ => PushAuthorizationStatus.notDetermined,
    };
  }

  @override
  Future<String?> refreshToken() async {
    final token = await messaging.refreshToken();
    if (token != null) {
      await _syncTokenQuietly(token);
    }
    return token;
  }

  @override
  Future<PushNotificationPayload?> takeInitialMessage() =>
      messaging.takeInitialMessage();

  Future<void> _syncTokenQuietly(String? token) async {
    final remote = tokenRemote;
    if (remote == null || token == null || token.isEmpty) return;
    try {
      await remote.register(token);
    } catch (error, stack) {
      debugPrint('[FCM] backend token register failed: $error\n$stack');
    }
  }
}
