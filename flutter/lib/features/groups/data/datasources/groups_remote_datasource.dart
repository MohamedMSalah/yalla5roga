import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';

abstract class GroupsDataSource {
  Future<List<Group>> getGroups();
  Future<Group> getGroup(String groupId);
  Future<Group> createGroup(Group group);
  Future<Group> updateGroup(Group group);
  Future<Group> addMember(String groupId, GroupMember member);
  Future<Group> removeMember(String groupId, String memberId);
  Future<void> leaveGroup(String groupId);
  GroupMember? memberById(String id);
  GroupMember? memberByPhone(String phone);
  String groupsForMember(String id);
  List<GroupMember> get contacts;
}

/// Live Dio datasource. Placeholder endpoints until the Node.js backend lands.
class GroupsRemoteDataSource implements GroupsDataSource {
  GroupsRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  List<GroupMember> get contacts => const [];

  @override
  Future<List<Group>> getGroups() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.groups,
      );
      final payload = apiPayload(response.data);
      final raw = payload['items'] ?? payload['groups'] ?? payload;
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map) _groupFromJson(Map<String, dynamic>.from(item)),
      ];
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
      return _groupFromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> createGroup(Group group) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.groups,
        data: _groupToJson(group),
      );
      return _groupFromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> updateGroup(Group group) async {
    try {
      final response = await _client.put<Map<String, dynamic>>(
        ApiConstants.group(group.id),
        data: _groupToJson(group),
      );
      return _groupFromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> addMember(String groupId, GroupMember member) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.groupMembers(groupId),
        data: member.toJson(),
      );
      return _groupFromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<Group> removeMember(String groupId, String memberId) async {
    try {
      final response = await _client.delete<Map<String, dynamic>>(
        '${ApiConstants.groupMembers(groupId)}/$memberId',
      );
      return _groupFromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiConstants.groupLeave(groupId),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  GroupMember? memberById(String id) => null;

  @override
  GroupMember? memberByPhone(String phone) => null;

  @override
  String groupsForMember(String id) => '';

  Group _groupFromJson(Map<String, dynamic> json) {
    return Group.fromJson({
      ...json,
      'id': apiString(json['id']) ?? '',
      'name': apiString(json['name']) ?? '',
      'outings': apiInt(json['outings']),
      'preview': apiString(json['preview']) ?? '',
      'bio': apiString(json['bio']) ?? apiString(json['description']) ?? '',
      'image': apiString(json['image']) ?? apiString(json['coverUrl']) ?? '',
      'lastMessage': apiString(json['lastMessage']),
      'unread': apiInt(json['unread']),
      'featured': apiBool(json['featured']),
      'decision': apiString(json['decision']),
      'cuserRole': apiString(json['cuserRole']) ?? apiString(json['myRole']),
    });
  }

  Map<String, dynamic> _groupToJson(Group group) => group.toJson();

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
