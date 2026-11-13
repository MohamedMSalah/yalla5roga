import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';

abstract class InvitationsRepository {
  /// Fetch invitations including decided history for the current user.
  Future<Either<Failure, List<GroupInvitation>>> getInvitations({
    bool forceRefresh = false,
  });

  /// Accept a pending invitation.
  Future<Either<Failure, void>> acceptInvitation(String invitationId);

  /// Decline a pending invitation.
  Future<Either<Failure, void>> declineInvitation(String invitationId);

  void clearCache();
}
