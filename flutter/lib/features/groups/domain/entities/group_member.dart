import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';

class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    required this.avatar,
    this.role = GroupRole.member,
    this.phone,
  });

  final String id;
  final String name;
  final String avatar;
  final GroupRole role;

  /// Egyptian phone in `+20…` form when known (for contact name matching).
  final String? phone;

  String get avatarUrl => avatar;

  GroupMember copyWith({
    String? id,
    String? name,
    String? avatar,
    GroupRole? role,
    String? phone,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'role': role.name,
    'phone': phone,
  };

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      role: GroupRole.fromApi(json['role'] as String?),
      phone: json['phone'] as String?,
    );
  }
}
