import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';

class Group {
  static const maxBioLength = 160;

  const Group({
    required this.id,
    required this.name,
    required this.outings,
    required this.image,
    required this.members,
    this.pendingMembers = const [],
    this.bio = '',
    this.listedMemberCount,
    this.cuserRole = GroupRole.member,
  });

  final String id;
  final String name;
  final int outings;
  final String image;

  /// Canonical membership list. Count and avatars are derived from this when loaded.
  final List<GroupMember> members;
  final List<GroupMember> pendingMembers;

  /// Optional group description / bio from the API.
  final String bio;

  /// `member_count` from list/create payloads when the full members list is not loaded yet.
  final int? listedMemberCount;

  final GroupRole cuserRole;

  String get coverUrl => image;

  int get memberCount {
    if (members.isNotEmpty) return members.length;
    return listedMemberCount ?? 0;
  }

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
    List<GroupMember>? pendingMembers,
    String? bio,
    int? listedMemberCount,
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
      pendingMembers: pendingMembers ?? this.pendingMembers,
      bio: bio ?? this.bio,
      listedMemberCount: listedMemberCount ?? this.listedMemberCount,
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
    'member_count': memberCount,
    'members': memberCount,
    'people': [for (final member in members) member.toJson()],
    'pendingMembers': [for (final member in pendingMembers) member.toJson()],
    'avatars': avatars,
  };

  factory Group.fromJson(Map<String, dynamic> json) {
    final peopleRaw = json['people'] ?? json['membersList'];
    final membersField = json['members'];
    final membersRaw =
        peopleRaw ?? (membersField is List ? membersField : null);
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

    final listedMemberCount =
        _readOptionalInt(json['member_count']) ??
        (membersField is num || membersField is String
            ? _readOptionalInt(membersField)
            : null);

    return Group(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      outings: _readInt(json['outings']),
      bio: json['bio'] as String? ?? json['description'] as String? ?? '',
      image: json['image'] as String? ?? json['coverUrl'] as String? ?? '',
      members: members,
      pendingMembers: [
        for (final item in json['pendingMembers'] as List? ?? const [])
          if (item is Map)
            GroupMember.fromJson(Map<String, dynamic>.from(item)),
      ],
      listedMemberCount: listedMemberCount,
      cuserRole: GroupRole.fromApi(
        json['cuserRole'] as String? ??
            json['myRole'] as String? ??
            json['my_role'] as String?,
      ),
    );
  }

  static int _readInt(Object? value) {
    return _readOptionalInt(value) ?? 0;
  }

  static int? _readOptionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
