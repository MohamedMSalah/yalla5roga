import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';

extension InvitationStatusL10n on InvitationStatus {
  String label(L10n l10n) => switch (this) {
    InvitationStatus.pending => l10n.pendingInvitationStatus,
    InvitationStatus.accepted => l10n.acceptedInvitationStatus,
    InvitationStatus.declined => l10n.declinedInvitationStatus,
    InvitationStatus.expired => l10n.expiredInvitationStatus,
    InvitationStatus.revoked => l10n.revokedInvitationStatus,
  };
}
