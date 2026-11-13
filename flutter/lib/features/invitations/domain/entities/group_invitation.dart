/// A group invitation addressed to the authenticated user, including history.
class GroupInvitation {
  const GroupInvitation({
    required this.invitationId,
    required this.groupId,
    required this.groupName,
    required this.groupImage,
    required this.invitedPhone,
    required this.status,
    required this.createdAt,
    required this.inviterName,
  });

  final String invitationId;
  final String groupId;
  final String groupName;
  final String groupImage;
  final String invitedPhone;
  final InvitationStatus status;
  final DateTime createdAt;
  final String inviterName;

  GroupInvitation copyWithStatus(InvitationStatus value) => GroupInvitation(
    invitationId: invitationId,
    groupId: groupId,
    groupName: groupName,
    groupImage: groupImage,
    invitedPhone: invitedPhone,
    status: value,
    createdAt: createdAt,
    inviterName: inviterName,
  );

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      invitationId: json['invitation_id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      groupImage: json['group_image'] as String? ?? '',
      invitedPhone: json['invited_phone'] as String? ?? '',
      status: InvitationStatus.fromApi(json['status'] as String?),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      inviterName: json['inviter_name'] as String? ?? '',
    );
  }
}

enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired,
  revoked;

  static InvitationStatus fromApi(String? value) {
    return InvitationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => InvitationStatus.pending,
    );
  }
}
