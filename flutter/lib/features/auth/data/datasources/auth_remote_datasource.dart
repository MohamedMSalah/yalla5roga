import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/auth/data/models/auth_session_model.dart';
import 'package:yalla_5roga/features/auth/data/models/user_model.dart';
import 'package:yalla_5roga/features/auth/domain/entities/phone_verification.dart';

/// Backend auth/profile APIs.
///
/// Email/password goes here (Neon). Google / Apple / phone OTP use Firebase on
/// the client, then [syncUser] with a Bearer Firebase ID token.
abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  });

  Future<AuthSessionModel> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
  });

  /// Creates / syncs the PostgreSQL `users` row after Firebase social/phone auth.
  /// Body is optional bootstrap fields; UID is taken from the Bearer token.
  Future<UserModel> syncUser({
    String? name,
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

  /// GET current Neon profile (`created_at`, `has_password`, …).
  Future<UserModel> getProfile();

  /// Confirm Neon password without changing it.
  Future<void> verifyPassword({required String password});

  /// Change Neon `password_hash`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) {
    return _postSession(ApiConstants.login, {
      'email': email.trim(),
      'password': password,
    });
  }

  @override
  Future<AuthSessionModel> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) {
    return _postSession(ApiConstants.signup, {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone.trim(),
    });
  }

  @override
  Future<UserModel> syncUser({
    String? name,
    String? email,
    String? phone,
    String? imageUrl,
  }) {
    return _postUser(ApiConstants.syncUser, {
      'name': ?name,
      'email': ?email,
      'phone': ?phone,
      'image_url': ?imageUrl,
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
      'image_url': ?imageUrl,
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
      throw _mapDio(error);
    }
  }

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.profile,
      );
      return UserModel.fromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _mapDio(error);
    }
  }

  @override
  Future<void> verifyPassword({required String password}) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.verifyPassword,
        data: {'password': password},
      );
    } on DioException catch (error) {
      throw _mapDio(error, authCredentials: true);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.changePassword,
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw _mapDio(error, authCredentials: true);
    }
  }

  Future<AuthSessionModel> _postSession(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      final session = AuthSessionModel.fromJson(apiPayload(response.data));
      if (session.customToken.isEmpty || session.uid.isEmpty) {
        throw const ServerException('Auth session missing customToken or uid');
      }
      return session;
    } on DioException catch (error) {
      throw _mapDio(error, authCredentials: true);
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
      throw _mapDio(error);
    }
  }

  Never _mapDio(DioException error, {bool authCredentials = false}) {
    final app = error.error is AppException
        ? error.error as AppException
        : ExceptionMapper.appExceptionFromDio(error);

    if (authCredentials &&
        (error.response?.statusCode == 401 ||
            app is AuthException ||
            app.statusCode == 401)) {
      throw AuthException(
        app.message.isNotEmpty ? app.message : 'Incorrect email or password',
        AuthErrorCodes.invalidCredential,
        app.statusCode ?? 401,
        app.httpMethod,
        app.endpoint,
        app.responseBody,
      ); // preserves Dio metadata for blueprint logging
    }
    throw app;
  }
}
