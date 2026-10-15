import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.outings,
    required this.image,
    required this.members,
    this.bio = '',

    this.cuserRole = GroupRole.member,
  });

  final String id;
  final String name;
  final int outings;
  final String image;

  /// Canonical membership list. Count and avatars are derived from this.
  final List<GroupMember> members;

  /// Optional group description / bio from the API.
  final String bio;
  final GroupRole cuserRole;

  String get coverUrl => image;

  int get memberCount => members.length;

  int get outingCount => outings;

  List<String> get avatars => [
    for (final member in members)
      if (member.avatar.isNotEmpty) member.avatar,
  ];

  bool get isOwner => cuserRole == GroupRole.owner;

  GroupMember? get owner {
    for (final member in members) {
      if (member.role == GroupRole.owner) return member;
    }
    return null;
  }

  GroupMember? memberById(String id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  bool containsMember({String? id, String? phone}) {
    for (final member in members) {
      if (id != null && (member.id == id || member.name == id)) return true;
      if (phone != null &&
          phone.isNotEmpty &&
          (member.phone == phone ||
              member.id == phone ||
              member.name == phone)) {
        return true;
      }
    }
    return false;
  }

  Group copyWith({
    String? id,
    String? name,
    int? outings,
    String? image,
    List<GroupMember>? members,
    String? bio,
    String? lastMessage,
    int? unread,
    bool? featured,
    String? decision,
    GroupRole? cuserRole,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      outings: outings ?? this.outings,
      image: image ?? this.image,
      members: members ?? this.members,
      bio: bio ?? this.bio,
      cuserRole: cuserRole ?? this.cuserRole,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'outings': outings,
    'image': image,
    'bio': bio,
    'cuserRole': cuserRole.name,
    'members': memberCount,
    'people': [for (final member in members) member.toJson()],
    'avatars': avatars,
  };

  factory Group.fromJson(Map<String, dynamic> json) {
    final peopleRaw = json['people'] ?? json['membersList'];
    final membersRaw = peopleRaw ?? json['members'];
    final parsedMembers = <GroupMember>[
      if (membersRaw is List)
        for (final item in membersRaw)
          if (item is Map)
            GroupMember.fromJson(Map<String, dynamic>.from(item)),
    ];

    final avatarUrls = <String>[
      for (final item in json['avatars'] as List? ?? const [])
        if (item is String && item.isNotEmpty) item,
    ];

    // List payloads may only send avatar URLs — synthesize members so the
    // entity stays linked to [GroupMember] instead of a parallel avatars list.
    final members = parsedMembers.isNotEmpty
        ? parsedMembers
        : [
            for (var i = 0; i < avatarUrls.length; i++)
              GroupMember(id: 'preview_$i', name: '', avatar: avatarUrls[i]),
          ];

    return Group(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      outings: _readInt(json['outings']),
      bio: json['bio'] as String? ?? json['description'] as String? ?? '',
      image: json['image'] as String? ?? json['coverUrl'] as String? ?? '',
      members: members,
      cuserRole: GroupRole.fromApi(json['cuserRole'] as String?),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
