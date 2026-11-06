import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/auth/data/models/user_model.dart';

/// Backend `POST /api/auth/login|signup` session payload.
class AuthSessionModel {
  const AuthSessionModel({
    required this.idToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.uid,
    required this.customToken,
    this.user,
  });

  final String idToken;
  final String refreshToken;
  final String expiresIn;
  final String uid;
  final String customToken;
  final UserModel? user;

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return AuthSessionModel(
      idToken: apiString(json['idToken']) ?? '',
      refreshToken: apiString(json['refreshToken']) ?? '',
      expiresIn: apiString(json['expiresIn']) ?? '3600',
      uid: apiString(json['uid']) ?? '',
      customToken: apiString(json['customToken']) ?? '',
      user: rawUser is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
    );
  }
}
