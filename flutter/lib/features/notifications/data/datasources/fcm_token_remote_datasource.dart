import 'dart:io';

import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';

class FcmTokenRemoteDataSource {
  FcmTokenRemoteDataSource(this._api);

  final ApiClient _api;

  Future<void> register(String token) async {
    await _api.post(
      ApiConstants.fcmToken,
      data: {
        'token': token,
        'platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
            ? 'android'
            : 'other',
      },
    );
  }

  Future<void> unregister(String token) async {
    await _api.delete('${ApiConstants.fcmToken}/${Uri.encodeComponent(token)}');
  }
}
