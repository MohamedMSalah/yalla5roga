import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.token,
    this.imageUrl,
    this.createdAt,
    this.hasPassword = false,
    this.phoneVerified = false,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? token;
  final String? imageUrl;

  /// Neon `users.created_at` — when the account joined the app.
  final DateTime? createdAt;

  /// True when Neon stores an email/password hash for this user.
  final bool hasPassword;

  /// True when Firebase has a verified phone number on this identity.
  final bool phoneVerified;

  User copyWith({
    String? name,
    String? phone,
    String? email,
    String? token,
    String? imageUrl,
    DateTime? createdAt,
    bool? hasPassword,
    bool? phoneVerified,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      token: token ?? this.token,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      hasPassword: hasPassword ?? this.hasPassword,
      phoneVerified: phoneVerified ?? this.phoneVerified,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    email,
    token,
    imageUrl,
    createdAt,
    hasPassword,
    phoneVerified,
  ];
}
