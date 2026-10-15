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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: apiString(json['id']) ?? '',
      name: apiString(json['name']) ?? '',
      phone: apiString(json['phone']) ?? '',
      email: apiString(json['email']),
      token: apiString(json['token']) ?? apiString(json['accessToken']),
      imageUrl: apiString(json['imageUrl']) ?? apiString(json['avatar']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'token': token,
      'imageUrl': imageUrl,
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
    );
  }
}
