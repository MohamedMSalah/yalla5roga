import 'package:equatable/equatable.dart';

/// Result of `POST /api/groups/:id/invitations`.
enum GroupInviteOutcome {
  memberAdded,
  alreadyMember,
  invited,
  alreadyPending,
}

class GroupInviteResult extends Equatable {
  const GroupInviteResult({
    required this.outcome,
    this.whatsappUrl,
    this.deepLink,
    this.invitationId,
    this.invitedPhone,
  });

  final GroupInviteOutcome outcome;
  final String? whatsappUrl;
  final String? deepLink;
  final String? invitationId;
  final String? invitedPhone;

  bool get isMembership =>
      outcome == GroupInviteOutcome.memberAdded ||
      outcome == GroupInviteOutcome.alreadyMember;

  bool get needsWhatsApp =>
      outcome == GroupInviteOutcome.invited ||
      outcome == GroupInviteOutcome.alreadyPending;

  factory GroupInviteResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['outcome'] as String?)?.trim() ?? '';
    final outcome = switch (raw) {
      'member_added' => GroupInviteOutcome.memberAdded,
      'already_member' => GroupInviteOutcome.alreadyMember,
      'already_pending' => GroupInviteOutcome.alreadyPending,
      _ => GroupInviteOutcome.invited,
    };

    return GroupInviteResult(
      outcome: outcome,
      whatsappUrl: _string(json['whatsapp_url']),
      deepLink: _string(json['deep_link']),
      invitationId: _string(json['invitation_id']),
      invitedPhone: _string(json['invited_phone']),
    );
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  @override
  List<Object?> get props => [
    outcome,
    whatsappUrl,
    deepLink,
    invitationId,
    invitedPhone,
  ];
}
