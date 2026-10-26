import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/chat/presentation/providers/outing_chat_provider.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_composer.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_mention_picker.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_mention_text.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_message_list.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_skeleton.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

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
  Timer? _closeTimer;

  String get _outingId => widget.event.id;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<OutingsProvider>().refreshLifecycle();
      final userId = context.read<AuthProvider>().user?.id;
      context.read<OutingChatProvider>().load(_outingId, userId: userId);
      context.read<OutingChatProvider>().markRead(_outingId);
      final groupId = widget.event.groupId;
      if (groupId != null && groupId.isNotEmpty) {
        await context.read<GroupsProvider>().ensureGroupLoaded(groupId);
      }
      if (mounted) _scheduleCloseCheck();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleCloseCheck() {
    _closeTimer?.cancel();
    final outing =
        context.read<OutingsProvider>().findById(_outingId) ?? widget.event;
    final closesAt = outing.chatClosesAt;
    if (closesAt == null) return;
    final delay = closesAt.difference(DateTime.now());
    if (delay.isNegative) return;
    _closeTimer = Timer(delay, () {
      if (mounted) setState(() {});
    });
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
    if (query.contains('\n') || query.contains(' ')) {
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

  List<GroupMember> _mentionCandidates(
    List<GroupMember> members, {
    String? currentUserId,
  }) {
    final query = _mentionQuery;
    if (query == null) return const [];
    final q = query.trim().toLowerCase();
    final filtered = members.where((member) {
      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          member.id == currentUserId) {
        return false;
      }
      final name = MemberDisplayName.resolve(member).toLowerCase();
      if (name.isEmpty) return false;
      if (q.isEmpty) return true;
      return name.contains(q) ||
          name.split(RegExp(r'\s+')).any((part) => part.startsWith(q));
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final sent = await context.read<OutingChatProvider>().sendMessage(
      outingId: _outingId,
      text: text,
      senderId: user.id,
      senderName: user.name,
      avatar: user.imageUrl,
    );
    if (!sent || !mounted) return;
    _controller.clear();
    _clearMention();
  }

  List<GroupMember> _groupMembers(
    GroupsProvider groups,
    OutingsProvider outings,
    Outing outing,
  ) {
    final byId = <String, GroupMember>{};
    void add(GroupMember member) {
      if (member.id.isEmpty) return;
      byId.putIfAbsent(member.id, () => member);
    }

    final groupId = outing.groupId ?? widget.event.groupId;
    if (groupId != null) {
      final group = groups.findById(groupId);
      if (group != null) {
        for (final member in group.members) {
          add(member);
        }
      }
    }
    for (final member in outings.membersForOuting(outing)) {
      add(member);
    }
    for (final guestId in outing.guestIds) {
      final member = groups.memberById(guestId);
      if (member != null) add(member);
    }
    return byId.values.toList();
  }

  Outing _liveOuting(OutingsProvider outings) =>
      outings.findById(_outingId) ?? widget.event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = context.watch<GroupsProvider>();
    final outings = context.watch<OutingsProvider>();
    final chat = context.watch<OutingChatProvider>();
    final outing = _liveOuting(outings);
    final closed = outing.isChatClosed;
    final members = _groupMembers(groups, outings, outing);
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final messages = chat.messagesFor(_outingId);
    final mentionCandidates = closed
        ? const <GroupMember>[]
        : _mentionCandidates(members, currentUserId: currentUserId);
    final showMentionAll = !closed && _showMentionAll(_mentionQuery);
    final showMentions = !closed && _mentionQuery != null;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppPageBar(title: outing.title, subtitle: l10n.outingChat),
      body: Column(
        children: [
          Expanded(
            child: chat.isInitialLoadingFor(_outingId)
                ? const OutingChatSkeleton()
                : messages.isEmpty
                ? AppEmptyState(
                    icon: Icons.chat_bubble_outline,
                    message: l10n.noChatMessages,
                    subtitle: closed
                        ? l10n.chatClosedHint
                        : l10n.noChatMessagesHint,
                  )
                : OutingChatMessageList(
                    messages: messages,
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
