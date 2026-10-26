import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_chat_composer.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_chat_mention_picker.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_chat_mention_text.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_chat_message_list.dart';

/// Static preview messages — chat is UI-only until a backend is wired.
const _fixedChatMessages = <ChatMessage>[
  ChatMessage(
    id: 'fixed_1',
    sender: 'Omar Farouk',
    senderId: 'u_omar',
    text: 'What time are we meeting?',
    time: '2:14 PM',
    isMine: false,
    deliveryStatus: MessageDeliveryStatus.seen,
  ),
  ChatMessage(
    id: 'fixed_2',
    sender: 'You',
    senderId: 'me',
    text: 'Around 8 works for me — outdoor seats if the weather stays nice.',
    time: '2:18 PM',
    isMine: true,
    deliveryStatus: MessageDeliveryStatus.seen,
  ),
  ChatMessage(
    id: 'fixed_3',
    sender: 'Nadia Elmasry',
    senderId: 'u_nadia',
    text: 'Perfect. I will bring dessert to share!',
    time: '2:22 PM',
    isMine: false,
    deliveryStatus: MessageDeliveryStatus.delivered,
  ),
];

class OutingChatPage extends StatefulWidget {
  const OutingChatPage({super.key, required this.event});

  final HeroSlide event;

  @override
  State<OutingChatPage> createState() => _OutingChatPageState();
}

class _OutingChatPageState extends State<OutingChatPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// Query after `@` while mentioning; null when the picker is hidden.
  String? _mentionQuery;
  int? _mentionStart;
  var _ignoreMentionUpdates = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OutingsProvider>().refreshLifecycle();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_ignoreMentionUpdates) return;

    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _clearMention();
      return;
    }

    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _clearMention();
      return;
    }

    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex < 0) {
      _clearMention();
      return;
    }
    if (atIndex > 0) {
      final previous = before[atIndex - 1];
      if (!_isMentionBoundary(previous)) {
        _clearMention();
        return;
      }
    }

    final query = before.substring(atIndex + 1);
    if (query.contains('\n')) {
      _clearMention();
      return;
    }

    setState(() {
      _mentionStart = atIndex;
      _mentionQuery = query;
    });
  }

  bool _isMentionBoundary(String char) =>
      char == ' ' || char == '\n' || char == '\t';

  void _clearMention() {
    if (_mentionQuery == null && _mentionStart == null) return;
    setState(() {
      _mentionQuery = null;
      _mentionStart = null;
    });
  }

  bool _showMentionAll(String? query) {
    if (query == null) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return outingChatMentionAllToken.startsWith(q) ||
        'everyone'.startsWith(q) ||
        'الجميع'.startsWith(q);
  }

  List<GroupMember> _mentionCandidates(List<GroupMember> members) {
    final query = _mentionQuery;
    if (query == null) return const [];
    final q = query.trim().toLowerCase();
    final filtered = members.where((member) {
      final name = MemberDisplayName.resolve(member).toLowerCase();
      if (q.isEmpty) return true;
      return name.startsWith(q) ||
          name.split(' ').any((part) => part.startsWith(q));
    }).toList();
    filtered.sort(
      (a, b) =>
          MemberDisplayName.resolve(a).compareTo(MemberDisplayName.resolve(b)),
    );
    return filtered;
  }

  void _insertMentionToken(String token) {
    final start = _mentionStart;
    if (start == null) return;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset.clamp(0, text.length);
    final mention = '@$token ';
    final next = text.replaceRange(start, cursor, mention);

    _ignoreMentionUpdates = true;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + mention.length),
    );
    setState(() {
      _mentionQuery = null;
      _mentionStart = null;
      _ignoreMentionUpdates = false;
    });
    _focusNode.requestFocus();
  }

  void _insertMention(GroupMember member) {
    _insertMentionToken(MemberDisplayName.resolve(member));
  }

  void _insertMentionAll() {
    _insertMentionToken(outingChatMentionAllToken);
  }

  void _send() {
    _controller.clear();
    _clearMention();
  }

  List<GroupMember> _groupMembers(
    GroupsProvider groups,
    OutingsProvider outings,
  ) {
    final groupId = widget.event.groupId;
    if (groupId != null) {
      final group = groups.findById(groupId);
      if (group != null) return group.members;
    }
    return outings.membersForOuting(widget.event);
  }

  bool _isChatClosed(OutingsProvider outings) {
    final outing = outings.findById(widget.event.id) ?? widget.event;
    return outing.isPastOuting || outing.status == OutingStatus.past;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = context.watch<GroupsProvider>();
    final outings = context.watch<OutingsProvider>();
    final closed = _isChatClosed(outings);
    final members = _groupMembers(groups, outings);
    final mentionCandidates = closed
        ? const <GroupMember>[]
        : _mentionCandidates(members);
    final showMentionAll = !closed && _showMentionAll(_mentionQuery);
    final showMentions =
        !closed &&
        _mentionQuery != null &&
        (showMentionAll ||
            mentionCandidates.isNotEmpty ||
            _mentionQuery!.isEmpty);

    return Scaffold(
      appBar: AppPageBar(title: widget.event.title, subtitle: l10n.outingChat),
      body: Column(
        children: [
          Expanded(
            child: OutingChatMessageList(
              messages: _fixedChatMessages,
              members: members,
              groups: groups,
            ),
          ),
          if (showMentions)
            OutingChatMentionPicker(
              members: mentionCandidates,
              showMentionAll: showMentionAll,
              mentionAllLabel: l10n.mentionAllLabel,
              mentionAllSubtitle: l10n.mentionAll,
              emptyLabel: l10n.noMembersToMention,
              title: l10n.mentionSomeone,
              onSelected: _insertMention,
              onMentionAll: _insertMentionAll,
            ),
          OutingChatComposer(
            closed: closed,
            controller: _controller,
            focusNode: _focusNode,
            hintText: l10n.writeMessage,
            chatClosedLabel: l10n.chatClosed,
            chatClosedHint: l10n.chatClosedHint,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
