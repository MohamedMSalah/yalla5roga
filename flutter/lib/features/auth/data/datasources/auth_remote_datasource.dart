import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/auth/data/models/user_model.dart';

/// Backend auth/profile APIs. Identity always comes from the verified
/// Firebase ID token on the `Authorization` header — never send a UID or
/// password for the server to trust as identity.
abstract class AuthRemoteDataSource {
  /// Creates the PostgreSQL `users` row after Firebase Auth signup.
  /// Body is profile fields only; UID is taken from the Bearer token.
  Future<UserModel> createUser({
    required String name,
    String? email,
    String? phone,
    String? imageUrl,
  });

  /// PATCH profile with only the fields that changed.
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? imageUrl,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<UserModel> createUser({
    required String name,
    String? email,
    String? phone,
    String? imageUrl,
  }) {
    return _postUser(ApiConstants.register, {
      'name': name,
      'email': ?email,
      'phone': ?phone,
      'imageUrl': ?imageUrl,
    });
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? imageUrl,
  }) async {
    final data = <String, dynamic>{
      'name': ?name,
      'email': ?email,
      'phone': ?phone,
      'imageUrl': ?imageUrl,
    };
    if (data.isEmpty) {
      throw const ServerException('No profile fields to update');
    }
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        ApiConstants.profile,
        data: data,
      );
      return UserModel.fromJson(apiPayload(response.data));
    } on DioException catch (error) {
      if (error.error is AppException) {
        throw error.error as AppException;
      }
      throw ServerException(error.message ?? 'Server error');
    }
  }

  Future<UserModel> _postUser(String path, Map<String, dynamic> data) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      return UserModel.fromJson(apiPayload(response.data));
    } on DioException catch (error) {
      if (error.error is AppException) {
        throw error.error as AppException;
      }
      throw ServerException(error.message ?? 'Server error');
    }
  }
}
