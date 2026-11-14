import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/widgets/connection_indicator.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
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
  final _selectedMentions = <({int start, int end, String id, String name})>[];
  String _previousText = '';
  String? _mentionQuery;
  int? _mentionStart;
  var _ignoreMentionUpdates = false;
  Timer? _closeTimer;
  ChatMessage? _editing;
  Timer? _editExpiryTimer;
  DateTime? _scheduledClose;
  OutingChatProvider? _chat;
  OutingsProvider? _outings;

  String get _outingId => widget.event.id;

  @override
  void initState() {
    super.initState();
    _outings = context.read<OutingsProvider>()..openOuting(_outingId);
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _chat = context.read<OutingChatProvider>();
      final outings = context.read<OutingsProvider>();
      final groups = context.read<GroupsProvider>();
      final userId = context.read<AuthProvider>().user?.id;
      unawaited(outings.refreshLifecycle(outingId: _outingId));
      await _chat!.subscribe(_outingId, userId: userId);
      if (!mounted) return;
      final groupId = widget.event.groupId;
      if (groupId != null && groupId.isNotEmpty) {
        await groups.ensureGroupLoaded(groupId);
      }
      if (mounted) _scheduleCloseCheck();
    });
  }

  @override
  void dispose() {
    _outings?.closeOuting(_outingId);
    _closeTimer?.cancel();
    _editExpiryTimer?.cancel();
    // Fire-and-forget leave; provider outlives this page.
    final chat = _chat;
    if (chat != null) {
      unawaited(chat.unsubscribe(_outingId));
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleCloseCheck() {
    final outing =
        context.read<OutingsProvider>().findById(_outingId) ?? widget.event;
    final closesAt = outing.chatClosesAt;
    if (closesAt == _scheduledClose) return;
    _scheduledClose = closesAt;
    _closeTimer?.cancel();
    if (closesAt == null) return;
    final delay = closesAt.difference(DateTime.now());
    if (delay.isNegative) return;
    _closeTimer = Timer(delay, () {
      if (mounted) setState(() {});
    });
  }

  void _onTextChanged() {
    final next = _controller.text;
    if (next != _previousText) {
      var prefix = 0;
      while (prefix < next.length &&
          prefix < _previousText.length &&
          next[prefix] == _previousText[prefix]) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < next.length - prefix &&
          suffix < _previousText.length - prefix &&
          next[next.length - suffix - 1] ==
              _previousText[_previousText.length - suffix - 1]) {
        suffix++;
      }
      final oldEnd = _previousText.length - suffix;
      final delta = next.length - _previousText.length;
      final retained = <({int start, int end, String id, String name})>[];
      for (final mention in _selectedMentions) {
        if (mention.end <= prefix) {
          retained.add(mention);
        } else if (mention.start >= oldEnd) {
          retained.add((
            start: mention.start + delta,
            end: mention.end + delta,
            id: mention.id,
            name: mention.name,
          ));
        }
      }
      _selectedMentions
        ..clear()
        ..addAll(retained);
      _previousText = next;
    }
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
    if (query.contains('\n') || query.length > 80) {
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
    final name = MemberDisplayName.resolve(member);
    final start = _mentionStart;
    if (start == null) return;
    _insertMentionToken(name);
    _selectedMentions.add((
      start: start,
      end: start + name.length + 1,
      id: member.id,
      name: name,
    ));
  }

  void _insertMentionAll() {
    _insertMentionToken(outingChatMentionAllToken);
  }

  Future<void> _send() async {
    final draft = _controller.value;
    var text = draft.text;
    final outing =
        context.read<OutingsProvider>().findById(_outingId) ?? widget.event;
    if (outing.isChatClosed || text.trim().isEmpty) return;
    final mentions = [..._selectedMentions]
      ..sort((a, b) => b.start.compareTo(a.start));
    for (final mention in mentions) {
      if (text.substring(mention.start, mention.end) == '@${mention.name}' &&
          (mention.end == text.length ||
              RegExp(r'[\s,.!?;:]').hasMatch(text[mention.end]))) {
        text = text.replaceRange(
          mention.start,
          mention.end,
          '<@${Uri.encodeComponent(mention.id)}|${Uri.encodeComponent(mention.name)}>',
        );
      }
    }
    text = text.trim();
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final editing = _editing;
    if (editing != null && !editing.canEditAt(DateTime.now())) {
      _cancelEdit();
      AppSnackBar.showError(context.l10n.messageEditExpired);
      return;
    }
    final sent = editing != null
        ? await context.read<OutingChatProvider>().mutateMessage(
            _outingId,
            editing.id,
            text: text,
          )
        : await context.read<OutingChatProvider>().sendMessage(
            outingId: _outingId,
            text: text,
            senderId: user.id,
            senderName: user.name,
            avatar: user.imageUrl,
          );
    if (!sent || !mounted || _controller.value != draft) return;
    _editExpiryTimer?.cancel();
    setState(() => _editing = null);
    _controller.clear();
    _selectedMentions.clear();
    _clearMention();
  }

  void _cancelEdit() {
    _editExpiryTimer?.cancel();
    setState(() => _editing = null);
    _controller.clear();
    _selectedMentions.clear();
    _clearMention();
  }

  void _startMention() {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final prefix = start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])
        ? ' @'
        : '@';
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, prefix),
      selection: TextSelection.collapsed(offset: start + prefix.length),
    );
    _focusNode.requestFocus();
  }

  void _edit(ChatMessage message) {
    final userId = context.read<AuthProvider>().user?.id;
    if (message.senderId != userId || !message.canEditAt(DateTime.now())) {
      AppSnackBar.showError(context.l10n.messageEditExpired);
      return;
    }
    _editExpiryTimer?.cancel();
    _editExpiryTimer = Timer(
      message.editDeadline!.difference(DateTime.now()),
      () {
        if (!mounted || _editing?.id != message.id) return;
        _cancelEdit();
        AppSnackBar.showError(context.l10n.messageEditExpired);
      },
    );
    _selectedMentions.clear();
    // Keep the stable IDs while presenting readable mention labels for editing.
    var text = message.text;
    final matches = RegExp(r'<@([^|<>]+)\|([^<>]*)>').allMatches(text).toList();
    for (final match in matches.reversed) {
      final name = Uri.decodeComponent(match[2]!);
      text = text.replaceRange(match.start, match.end, '@$name');
    }
    _controller.text = text;
    _selectedMentions.clear();
    var offset = 0;
    for (final match in matches) {
      final name = Uri.decodeComponent(match[2]!);
      final start = match.start + offset;
      _selectedMentions.add((
        start: start,
        end: start + name.length + 1,
        id: Uri.decodeComponent(match[1]!),
        name: name,
      ));
      offset += name.length + 1 - (match.end - match.start);
    }
    setState(() => _editing = message);
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
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
    _scheduleCloseCheck();
    final members = _groupMembers(groups, outings, outing);
    final currentUser = context.watch<AuthProvider>().user;
    final currentUserId = currentUser?.id;
    final messages = chat.messagesFor(_outingId);
    final mentionCandidates = closed
        ? const <GroupMember>[]
        : _mentionCandidates(members, currentUserId: currentUserId);
    final showMentionAll = !closed && _showMentionAll(_mentionQuery);
    final showMentions = !closed && _mentionQuery != null;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppPageBar(title: l10n.outingChat, subtitle: outing.title),
      body: Center(
        child: SizedBox(
          width: Responsive.contentMaxWidth,
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ConnectionIndicator(
                  connected: chat.isRoomConnected(_outingId),
                  reconnecting: chat.isRoomReconnecting(_outingId),
                  label: chat.isRoomConnected(_outingId)
                      ? l10n.chatConnected
                      : chat.isRoomReconnecting(_outingId)
                      ? l10n.chatReconnecting
                      : l10n.chatOffline,
                ),
              ),
              Expanded(
                child: chat.isInitialLoadingFor(_outingId)
                    ? const OutingChatSkeleton()
                    : messages.isEmpty && chat.errorMessage != null
                    ? AppErrorState(
                        message: chat.errorMessage!,
                        onRetry: () => chat.load(_outingId, forceRefresh: true),
                      )
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
                        onEdit: closed ? null : _edit,
                        onDelete: closed
                            ? null
                            : (message) =>
                                  chat.mutateMessage(_outingId, message.id),
                        onRetry: closed ? null : chat.retryMessage,
                        currentUserId: currentUserId,
                        currentUserName: currentUser?.name,
                        loadingOlder: chat.isLoadingOlder(_outingId),
                        onLoadOlder: chat.hasOlder(_outingId)
                            ? () => chat.loadOlder(_outingId)
                            : null,
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
                hintText: _editing != null
                    ? l10n.editMessage
                    : l10n.writeMessage,
                busy: chat.isSending(_outingId),
                onMention: closed ? null : _startMention,
                onCancelEdit: _editing == null ? null : _cancelEdit,
                chatClosedLabel: l10n.chatClosed,
                chatClosedHint: l10n.chatCompletionHint,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
