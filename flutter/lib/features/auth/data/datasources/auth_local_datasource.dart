import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/features/auth/data/models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);

  Future<UserModel> getCachedUser();

  Future<void> clear();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<void> cacheUser(UserModel user) async {
    await _prefs.setString(
      AppConstants.userCacheKey,
      jsonEncode(user.toJson()),
    );
    if (user.token != null && user.token!.isNotEmpty) {
      await _prefs.setString(AppConstants.tokenKey, user.token!);
    } else {
      await _prefs.remove(AppConstants.tokenKey);
    }
  }

  @override
  Future<UserModel> getCachedUser() async {
    final raw = _prefs.getString(AppConstants.userCacheKey);
    if (raw == null) {
      throw const CacheException('No cached user');
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const CacheException('No cached user');
      }
      return UserModel.fromJson(Map<String, dynamic>.from(decoded));
    } on CacheException {
      rethrow;
    } catch (_) {
      throw const CacheException('No cached user');
    }
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(AppConstants.userCacheKey);
    await _prefs.remove(AppConstants.tokenKey);
  }
}
