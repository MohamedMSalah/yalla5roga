class GroupInvitationRecord {
  const GroupInvitationRecord({
    required this.id,
    required this.phone,
    required this.inviteeName,
    required this.inviterName,
    required this.status,
    required this.createdAt,
  });
  final String id, phone, inviteeName, inviterName, status;
  final DateTime? createdAt;
  factory GroupInvitationRecord.fromJson(Map<String, dynamic> json) =>
      GroupInvitationRecord(
        id: json['invitation_id'] as String? ?? '',
        phone: json['invited_phone'] as String? ?? '',
        inviteeName: json['invitee_name'] as String? ?? '',
        inviterName: json['inviter_name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
  Map<String, dynamic> toJson() => {
    'invitation_id': id,
    'invited_phone': phone,
    'invitee_name': inviteeName,
    'inviter_name': inviterName,
    'status': status,
    'created_at': createdAt?.toIso8601String(),
  };
}
