import 'package:yalla_5roga/features/invites/domain/entities/pending_group_invite.dart';

/// Parses backend invite deep links into a [PendingGroupInvite].
///
/// Supported shapes:
/// - `https://yalla5roga.com/invite/{invitationId}?groupId={groupId}`
/// - `yalla5roga://invite?invitationId={id}&groupId={groupId}`
class InviteLinkParser {
  const InviteLinkParser({
    this.appScheme = 'yalla5roga',
    this.httpsHosts = const {'yalla5roga.com', 'www.yalla5roga.com'},
  });

  final String appScheme;
  final Set<String> httpsHosts;

  PendingGroupInvite? parse(Uri uri) {
    final custom = _parseCustomScheme(uri);
    if (custom != null) return custom;
    return _parseHttps(uri);
  }

  PendingGroupInvite? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    return parse(uri);
  }

  PendingGroupInvite? _parseCustomScheme(Uri uri) {
    if (uri.scheme != appScheme) return null;

    final isInviteHost = uri.host.toLowerCase() == 'invite';
    final isInvitePath =
        uri.path == '/invite' || uri.pathSegments.contains('invite');
    if (!isInviteHost && !isInvitePath) return null;

    final invitationId =
        uri.queryParameters['invitationId']?.trim() ??
        uri.queryParameters['invitation_id']?.trim() ??
        '';
    final groupId =
        uri.queryParameters['groupId']?.trim() ??
        uri.queryParameters['group_id']?.trim() ??
        '';

    final invite = PendingGroupInvite(
      invitationId: invitationId,
      groupId: groupId,
    );
    return invite.isValid ? invite : null;
  }

  PendingGroupInvite? _parseHttps(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final host = uri.host.toLowerCase();
    if (!httpsHosts.contains(host)) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2 || segments.first.toLowerCase() != 'invite') {
      return null;
    }

    final invitationId = segments[1].trim();
    final groupId =
        uri.queryParameters['groupId']?.trim() ??
        uri.queryParameters['group_id']?.trim() ??
        '';

    final invite = PendingGroupInvite(
      invitationId: invitationId,
      groupId: groupId,
    );
    return invite.isValid ? invite : null;
  }
}
