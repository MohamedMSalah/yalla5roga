import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.phone,
    super.email,
    super.token,
    super.imageUrl,
    super.createdAt,
    super.hasPassword,
    super.phoneVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: apiString(json['id']) ?? '',
      name: apiString(json['name']) ?? '',
      phone: apiString(json['phone']) ?? '',
      email: apiString(json['email']),
      token: apiString(json['token']) ?? apiString(json['accessToken']),
      imageUrl:
          apiString(json['image_url']) ??
          apiString(json['imageUrl']) ??
          apiString(json['avatar']),
      createdAt: _parseDate(
        json['created_at'] ?? json['createdAt'],
      ),
      hasPassword: apiBool(
        json['has_password'] ?? json['hasPassword'] ?? false,
      ),
      phoneVerified: apiBool(
        json['phone_verified'] ?? json['phoneVerified'] ?? false,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'imageUrl': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'has_password': hasPassword,
      'phone_verified': phoneVerified,
    };
  }

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email,
      token: user.token,
      imageUrl: user.imageUrl,
      createdAt: user.createdAt,
      hasPassword: user.hasPassword,
      phoneVerified: user.phoneVerified,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    final text = apiString(value);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}
