import 'dart:io';

import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:dio/dio.dart';

class FcmTokenRemoteDataSource {
  FcmTokenRemoteDataSource(this._api);

  final ApiClient _api;

  Future<void> register(String token, {String? expectedUserId}) async {
    await _api.post(
      ApiConstants.fcmToken,
      data: {
        'token': token,
        'notificationVersion': 2,
        'platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
            ? 'android'
            : 'other',
      },
      options: Options(
        extra: {if (expectedUserId != null) expectedUserIdKey: expectedUserId},
      ),
    );
  }

  Future<void> unregister(String token) async {
    await _api.delete('${ApiConstants.fcmToken}/${Uri.encodeComponent(token)}');
  }
}
