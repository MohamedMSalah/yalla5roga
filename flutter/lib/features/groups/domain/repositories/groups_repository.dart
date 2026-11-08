import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_invite_result.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';

abstract class GroupsRepository {
  Future<Either<Failure, List<Group>>> getGroups({bool forceRefresh = false});

  Future<Either<Failure, Group>> getGroup(
    String groupId, {
    bool forceRefresh = false,
  });

  Future<Either<Failure, Group>> createGroup(Group group);

  Future<Either<Failure, Group>> updateGroup(Group group);

  Future<Either<Failure, Group>> addMember(String groupId, GroupMember member);

  /// Invite by phone: adds existing verified users, or creates a pending
  /// `group_invitations` row + WhatsApp payload for non-users.
  Future<Either<Failure, GroupInviteResult>> inviteByPhone({
    required String groupId,
    required String phoneNumber,
  });

  Future<Either<Failure, Group>> removeMember(String groupId, String memberId);

  Future<Either<Failure, void>> leaveGroup(String groupId);

  GroupMember? memberById(String id);

  GroupMember? memberByPhone(String phone);

  String groupsForMember(String id);

  List<GroupMember> get contacts;

  void clearCache();
}
