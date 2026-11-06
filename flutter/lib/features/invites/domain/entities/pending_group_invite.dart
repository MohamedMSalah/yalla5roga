import 'package:equatable/equatable.dart';

/// Stashed group invitation opened via deep link before auth / navigation is ready.
class PendingGroupInvite extends Equatable {
  const PendingGroupInvite({
    required this.invitationId,
    required this.groupId,
  });

  final String invitationId;
  final String groupId;

  Map<String, String> toJson() => {
    'invitationId': invitationId,
    'groupId': groupId,
  };

  factory PendingGroupInvite.fromJson(Map<String, dynamic> json) {
    return PendingGroupInvite(
      invitationId: '${json['invitationId'] ?? ''}',
      groupId: '${json['groupId'] ?? ''}',
    );
  }

  bool get isValid => invitationId.isNotEmpty && groupId.isNotEmpty;

  @override
  List<Object?> get props => [invitationId, groupId];
}
