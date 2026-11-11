import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_mention_text.dart';

class OutingChatMessageList extends StatelessWidget {
  const OutingChatMessageList({
    super.key,
    required this.messages,
    required this.members,
    this.currentUserId,
    this.currentUserName,
    this.onLoadOlder,
    this.loadingOlder = false,
  });

  final List<ChatMessage> messages;
  final List<GroupMember> members;
  final String? currentUserId;
  final String? currentUserName;
  final VoidCallback? onLoadOlder;
  final bool loadingOlder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    final byId = {for (final member in members) member.id: member};
    return ListView.builder(
      reverse: true,
      padding: Responsive.pagePadding(),
      itemCount: messages.length + (onLoadOlder == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return TextButton(
            onPressed: loadingOlder ? null : onLoadOlder,
            child: loadingOlder
                ? const CircularProgressIndicator.adaptive()
                : Text(l10n.olderChatMessages),
          );
        }
        final message = messages[messages.length - 1 - index];
        final isMine =
            currentUserId != null && message.senderId == currentUserId;
        final align =
            (isMine
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart)
                .resolve(Directionality.of(context));
        final member = byId[message.senderId];
        final profileName = isMine ? currentUserName?.trim() : null;
        final name = profileName?.isNotEmpty == true
            ? profileName!
            : message.sender.trim().isNotEmpty
            ? message.sender.trim()
            : member != null
            ? MemberDisplayName.resolve(member)
            : l10n.chatUnknownSender;
        final senderName = isMine ? '$name (${l10n.you})' : name;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == messages.length - 1 ? 0 : 10.h,
          ),
          child: Align(
            alignment: align,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMine) ...[
                  AppNetworkImage.avatar(
                    url: message.avatar ?? '',
                    width: 28.w,
                    height: 28.w,
                    radius: 999,
                  ),
                  8.gapW,
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: (MediaQuery.sizeOf(context).width * 0.72)
                          .clamp(200.w, 320.w)
                          .toDouble(),
                    ),
                    padding: Responsive.padding(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine ? AppColors.brand600 : palette.surface,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: isMine
                          ? null
                          : [
                              BoxShadow(
                                color: palette.shadow,
                                blurRadius: 10.w,
                                offset: Offset(0, 4.h),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: context.texts.labelMedium?.copyWith(
                            color: isMine ? Colors.white : palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        4.gapH,
                        OutingChatMentionText(
                          text: message.text,
                          members: members,
                          style: TextStyle(
                            color: isMine ? Colors.white : palette.textPrimary,
                            fontSize: Responsive.fontSm,
                          ),
                          mentionStyle: TextStyle(
                            color: isMine ? Colors.white : AppColors.brand600,
                            fontSize: Responsive.fontSm,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        4.gapH,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(context, message),
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white70
                                    : palette.textMuted,
                                fontSize: Responsive.fontXs,
                              ),
                            ),
                            if (isMine) ...[
                              4.gapW,
                              Icon(
                                _statusIcon(message.deliveryStatus),
                                size: 14.sp,
                                color: _statusColor(message.deliveryStatus),
                                semanticLabel: switch (message.deliveryStatus) {
                                  MessageDeliveryStatus.pending =>
                                    context.l10n.chatMessagePending,
                                  MessageDeliveryStatus.failed =>
                                    context.l10n.chatMessageFailed,
                                  _ => null,
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatTime(BuildContext context, ChatMessage message) {
  final l10n = context.l10n;
  final sentAt = message.sentAt;
  if (sentAt != null) return l10n.formatTime(sentAt);
  return l10n.formatClock(message.time);
}

IconData _statusIcon(MessageDeliveryStatus status) {
  return switch (status) {
    MessageDeliveryStatus.pending => Icons.schedule,
    MessageDeliveryStatus.failed => Icons.error_outline,
    MessageDeliveryStatus.sent => Icons.check,
    MessageDeliveryStatus.delivered ||
    MessageDeliveryStatus.seen => Icons.done_all,
  };
}

Color _statusColor(MessageDeliveryStatus status) {
  return switch (status) {
    MessageDeliveryStatus.seen => const Color(0xFF90CAF9),
    _ => Colors.white70,
  };
}
