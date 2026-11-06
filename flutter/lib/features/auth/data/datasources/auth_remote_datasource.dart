import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
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
    if (error.error is AppException) {
      final app = error.error as AppException;
      if (authCredentials &&
          (error.response?.statusCode == 401 || app is AuthException)) {
        throw AuthException(
          app.message.isNotEmpty
              ? app.message
              : 'Incorrect email or password. Check your details and try again.',
          AuthErrorCodes.invalidCredential,
        );
      }
      throw app;
    }
    final status = error.response?.statusCode;
    final message = _messageFromBody(error) ?? error.message ?? 'Server error';
    if (authCredentials && status == 401) {
      throw AuthException(message, AuthErrorCodes.invalidCredential);
    }
    if (status == 401 || status == 403) {
      throw AuthException(message);
    }
    if (status == 409) {
      throw ServerException(message);
    }
    throw ServerException(message);
  }

  String? _messageFromBody(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
