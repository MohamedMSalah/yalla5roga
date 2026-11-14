import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/message_bubble.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/chat_date_separator.dart';

class OutingChatMessageList extends StatefulWidget {
  const OutingChatMessageList({
    super.key,
    required this.messages,
    required this.members,
    this.currentUserId,
    this.currentUserName,
    this.onLoadOlder,
    this.loadingOlder = false,
    this.onEdit,
    this.onDelete,
    this.onRetry,
  });
  final List<ChatMessage> messages;
  final List<GroupMember> members;
  final String? currentUserId;
  final String? currentUserName;
  final VoidCallback? onLoadOlder;
  final bool loadingOlder;
  final ValueChanged<ChatMessage>? onEdit, onDelete, onRetry;
  @override
  State<OutingChatMessageList> createState() => _OutingChatMessageListState();
}

class _OutingChatMessageListState extends State<OutingChatMessageList> {
  final _scroll = ScrollController();
  String? _insertedId;
  @override
  void didUpdateWidget(covariant OutingChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final last = widget.messages.lastOrNull;
    if (last != null && last.id != oldWidget.messages.lastOrNull?.id) {
      _insertedId = last.id;
      if (_scroll.hasClients &&
          (_scroll.offset < 100 || last.senderId == widget.currentUserId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(
              0,
              duration: AppMotion.of(context, AppMotion.standard),
              curve: AppMotion.enter,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final member in widget.members) member.id: member};
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: Responsive.pagePadding(),
      itemCount: widget.messages.length + (widget.onLoadOlder == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == widget.messages.length) {
          return TextButton(
            onPressed: widget.loadingOlder ? null : widget.onLoadOlder,
            child: widget.loadingOlder
                ? const CircularProgressIndicator.adaptive()
                : Text(context.l10n.olderChatMessages),
          );
        }
        final position = widget.messages.length - 1 - index;
        final message = widget.messages[position];
        final previous = position > 0 ? widget.messages[position - 1] : null;
        final sameDay = _sameDay(message.sentAt, previous?.sentAt);
        final grouped =
            sameDay &&
            previous?.senderId == message.senderId &&
            message.sentAt!.difference(previous!.sentAt!).inMinutes.abs() < 5;
        final mine =
            widget.currentUserId != null &&
            message.senderId == widget.currentUserId;
        final member = byId[message.senderId];
        final name = message.sender.trim().isNotEmpty
            ? message.sender.trim()
            : mine && widget.currentUserName?.isNotEmpty == true
            ? widget.currentUserName!
            : member != null
            ? MemberDisplayName.resolve(member)
            : context.l10n.chatUnknownSender;
        final mutable =
            mine && message.text.isNotEmpty && !message.id.startsWith('local_');
        final bubble = MessageBubble(
          message: message,
          name: mine ? '$name (${context.l10n.you})' : name,
          mine: mine,
          grouped: grouped,
          members: widget.members,
          onEdit: mutable && widget.onEdit != null
              ? () => widget.onEdit!(message)
              : null,
          onDelete: mutable && widget.onDelete != null
              ? () => widget.onDelete!(message)
              : null,
          onRetry:
              mine &&
                  message.deliveryStatus == MessageDeliveryStatus.failed &&
                  widget.onRetry != null
              ? () => widget.onRetry!(message)
              : null,
        );
        return Column(
          key: ValueKey(message.id),
          children: [
            if (!sameDay && message.sentAt != null)
              ChatDateSeparator(date: message.sentAt!),
            TweenAnimationBuilder<double>(
              key: ValueKey('insert-${message.id}'),
              tween: Tween(begin: message.id == _insertedId ? 0 : 1, end: 1),
              duration: AppMotion.of(context, AppMotion.standard),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: bubble,
            ),
          ],
        );
      },
    );
  }
}
