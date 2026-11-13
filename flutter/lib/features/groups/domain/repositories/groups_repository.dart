import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_invite_result.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';

abstract class GroupsRepository {
  Future<Either<Failure, void>> deleteGroup(String id);
  Future<Either<Failure, List<Group>>> getGroups({bool forceRefresh = false});

  Future<Either<Failure, Group>> getGroup(
    String groupId, {
    bool forceRefresh = false,
    bool allowStale = true,
  });

  Future<Either<Failure, Group>> createGroup(Group group);

  Future<Either<Failure, Group>> updateGroup(
    String groupId, {
    String? name,
    String? bio,
    String? image,
  });

  Future<Either<Failure, Group>> addMember(String groupId, GroupMember member);

  /// Invite by phone; membership requires explicit acceptance of the pending invitation.
  Future<Either<Failure, GroupInviteResult>> inviteByPhone({
    required String groupId,
    required String phoneNumber,
    bool whatsappOptIn = false,
  });

  Future<Either<Failure, Group>> removeMember(
    String groupId,
    String memberId, {
    bool pending = false,
  });

  Future<Either<Failure, void>> leaveGroup(String groupId);

  GroupMember? memberById(String id);

  GroupMember? memberByPhone(String phone);

  String groupsForMember(String id);

  List<GroupMember> get contacts;

  void clearCache();
}
