import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/core/utils/remote_image_url.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_invite_result.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_role.dart';

abstract class GroupsDataSource {
  Future<List<Group>> getGroups();
  Future<Group> getGroup(String groupId);
  Future<Group> createGroup(Group group);
  Future<Group> updateGroup(Group group);
  Future<Group> addMember(String groupId, GroupMember member);
  Future<Group> removeMember(String groupId, String memberId);
  Future<void> leaveGroup(String groupId, String userId);
  Future<GroupInviteResult> inviteByPhone({
    required String groupId,
    required String phoneNumber,
  });
  GroupMember? memberById(String id);
  GroupMember? memberByPhone(String phone);
  String groupsForMember(String id);
  List<GroupMember> get contacts;
}

/// Live Dio datasource aligned with `/api/groups` OpenAPI contract.
class GroupsRemoteDataSource implements GroupsDataSource {
  GroupsRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  List<GroupMember> get contacts => const [];

  @override
  Future<List<Group>> getGroups() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.groupsCuser,
      );
      final items = apiObjectList(
        response.data,
        aliases: const ['groups', 'items'],
      );
      return [for (final item in items) _groupFromJson(item)];
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> getGroup(String groupId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.group(groupId),
      );
      final group = _groupFromJson(apiPayload(response.data));
      final members = await _fetchMembers(groupId);
      return group.copyWith(members: members);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> createGroup(Group group) async {
    try {
      final imageUrl = remoteImageUrlOrNull(group.image);
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.groups,
        data: {
          'name': group.name,
          if (group.bio.isNotEmpty) 'bio': group.bio,
          if (imageUrl != null) 'image_url': imageUrl,
        },
      );
      final created = _groupFromJson(apiPayload(response.data));
      // Reload members so the creator/owner card is present immediately.
      final withMembers = await getGroup(created.id);
      return withMembers.copyWith(
        cuserRole: GroupRole.owner,
        listedMemberCount: withMembers.memberCount > 0
            ? withMembers.memberCount
            : (created.listedMemberCount ?? 1),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> updateGroup(Group group) async {
    try {
      final imageUrl = remoteImageUrlOrNull(group.image);
      final response = await _client.patch<Map<String, dynamic>>(
        ApiConstants.group(group.id),
        data: {
          'name': group.name,
          'bio': group.bio,
          // Local paths are preview-only until an upload pipeline exists.
          if (imageUrl != null) 'image_url': imageUrl,
        },
      );
      return _groupFromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> addMember(String groupId, GroupMember member) async {
    try {
      final phone = member.phone?.trim() ?? '';
      if (phone.isEmpty) {
        throw const ServerException('phoneNumber is required to add a member');
      }
      await _client.post<Map<String, dynamic>>(
        ApiConstants.groupMembers(groupId),
        data: {
          'phoneNumber': phone,
          if (member.role == GroupRole.owner) 'role': 'owner',
        },
      );
      return getGroup(groupId);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> removeMember(String groupId, String memberId) async {
    try {
      await _client.delete<Map<String, dynamic>>(
        ApiConstants.groupMember(groupId, memberId),
      );
      return getGroup(groupId);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      // Phase A: no dedicated leave route — DELETE self as member.
      await _client.delete<Map<String, dynamic>>(
        ApiConstants.groupMember(groupId, userId),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<GroupInviteResult> inviteByPhone({
    required String groupId,
    required String phoneNumber,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.groupInvitations(groupId),
        data: {'phoneNumber': phoneNumber},
      );
      return GroupInviteResult.fromJson(apiPayload(response.data));
    } on DioException catch (error) {
      // already_pending / already_member return 409 with invite payload.
      final conflict = _inviteConflict(error);
      if (conflict != null) return conflict;
      throw _unwrap(error);
    }
  }

  GroupInviteResult? _inviteConflict(DioException error) {
    if (error.response?.statusCode != 409) return null;
    final body = error.response?.data;
    if (body is! Map) return null;
    final nested = body['data'];
    if (nested is! Map) return null;
    final payload = Map<String, dynamic>.from(nested);
    final outcome = payload['outcome'] as String?;
    if (outcome != 'already_pending' && outcome != 'already_member') {
      return null;
    }
    return GroupInviteResult.fromJson(payload);
  }

  @override
  GroupMember? memberById(String id) => null;

  @override
  GroupMember? memberByPhone(String phone) => null;

  @override
  String groupsForMember(String id) => '';

  Future<List<GroupMember>> _fetchMembers(String groupId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.groupMembers(groupId),
    );
    final items = apiObjectList(
      response.data,
      aliases: const ['items', 'members'],
    );
    return [for (final item in items) _memberFromJson(item)];
  }

  GroupMember _memberFromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: apiString(json['user_id']) ?? apiString(json['id']) ?? '',
      name: apiString(json['name']) ?? apiString(json['user_id']) ?? '',
      avatar: apiString(json['avatar']) ?? apiString(json['image_url']) ?? '',
      role: GroupRole.values.firstWhere(
        (role) => role.name == (apiString(json['role']) ?? 'member'),
        orElse: () => GroupRole.member,
      ),
      phone: apiString(json['phone']) ?? '',
    );
  }

  Group _groupFromJson(Map<String, dynamic> json) {
    return Group.fromJson({
      ...json,
      'id': apiString(json['id']) ?? '',
      'name': apiString(json['name']) ?? '',
      'outings': apiInt(json['outings']),
      'preview': apiString(json['preview']) ?? '',
      'bio': apiString(json['bio']) ?? apiString(json['description']) ?? '',
      'image':
          apiString(json['image_url']) ??
          apiString(json['image']) ??
          apiString(json['coverUrl']) ??
          '',
      'lastMessage': apiString(json['lastMessage']),
      'unread': apiInt(json['unread']),
      'featured': apiBool(json['featured']),
      'decision': apiString(json['decision']),
      if (json['member_count'] != null)
        'member_count': apiInt(json['member_count']),
      'cuserRole':
          apiString(json['cuserRole']) ??
          apiString(json['myRole']) ??
          apiString(json['my_role']),
    });
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
