import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.token,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? token;
  final String? imageUrl;

  User copyWith({
    String? name,
    String? phone,
    String? email,
    String? token,
    String? imageUrl,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      token: token ?? this.token,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email, token, imageUrl];
}
