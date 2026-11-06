import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/features/invites/data/invite_link_parser.dart';

void main() {
  const parser = InviteLinkParser();

  test('parses HTTPS invite App Link', () {
    final invite = parser.tryParse(
      'https://yalla5roga.com/invite/abc-123?groupId=11111111-1111-4111-8111-111111111111',
    );
    expect(invite, isNotNull);
    expect(invite!.invitationId, 'abc-123');
    expect(invite.groupId, '11111111-1111-4111-8111-111111111111');
  });

  test('parses custom scheme invite', () {
    final invite = parser.tryParse(
      'yalla5roga://invite?invitationId=inv-9&groupId=group-9',
    );
    expect(invite, isNotNull);
    expect(invite!.invitationId, 'inv-9');
    expect(invite.groupId, 'group-9');
  });

  test('rejects unrelated hosts and missing groupId', () {
    expect(
      parser.tryParse('https://example.com/invite/abc?groupId=g1'),
      isNull,
    );
    expect(parser.tryParse('https://yalla5roga.com/invite/abc'), isNull);
  });
}
