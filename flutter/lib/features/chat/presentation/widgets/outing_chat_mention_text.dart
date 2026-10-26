import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';

/// Token inserted for @all mentions (must match composer insert logic).
const outingChatMentionAllToken = 'all';

class OutingChatMentionText extends StatelessWidget {
  const OutingChatMentionText({
    super.key,
    required this.text,
    required this.members,
    required this.style,
    required this.mentionStyle,
  });

  final String text;
  final List<GroupMember> members;
  final TextStyle style;
  final TextStyle mentionStyle;

  @override
  Widget build(BuildContext context) {
    final names = <String>[
      outingChatMentionAllToken,
      ...members
          .map(MemberDisplayName.resolve)
          .where((name) => name.trim().isNotEmpty),
    ]..sort((a, b) => b.length.compareTo(a.length));

    if (!text.contains('@')) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      if (text[i] != '@') {
        final nextAt = text.indexOf('@', i);
        final end = nextAt < 0 ? text.length : nextAt;
        spans.add(TextSpan(text: text.substring(i, end), style: style));
        i = end;
        continue;
      }

      var matched = false;
      for (final name in names) {
        final token = '@$name';
        if (text.startsWith(token, i)) {
          final boundary = i + token.length;
          final okBoundary =
              boundary >= text.length ||
              RegExp(r'[\s,.!?;:]').hasMatch(text[boundary]);
          if (okBoundary) {
            spans.add(TextSpan(text: token, style: mentionStyle));
            i = boundary;
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        spans.add(TextSpan(text: '@', style: style));
        i += 1;
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}
