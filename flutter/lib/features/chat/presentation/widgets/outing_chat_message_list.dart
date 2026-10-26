import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_chat_mention_text.dart';

class OutingChatMessageList extends StatelessWidget {
  const OutingChatMessageList({
    super.key,
    required this.messages,
    required this.members,
    required this.groups,
  });

  final List<ChatMessage> messages;
  final List<GroupMember> members;
  final GroupsProvider groups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return ListView.builder(
      padding: Responsive.pagePadding(),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final align = message.isMine
            ? Alignment.centerRight
            : Alignment.centerLeft;
        final member = message.senderId == null
            ? null
            : groups.memberById(message.senderId!);
        final senderName = l10n.digits(
          member != null ? MemberDisplayName.resolve(member) : message.sender,
        );
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
                if (!message.isMine) ...[
                  AppNetworkImage.avatar(
                    url: message.avatar ?? '',
                    width: 28.w,
                    height: 28.w,
                    radius: 999,
                  ),
                  8.gapW,
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 240.w),
                  child: Container(
                    padding: Responsive.padding(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: message.isMine
                          ? AppColors.brand600
                          : palette.surface,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: message.isMine
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
                        if (!message.isMine)
                          Text(
                            senderName,
                            style: TextStyle(
                              color: AppColors.brand600,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        OutingChatMentionText(
                          text: message.text,
                          members: members,
                          style: TextStyle(
                            color: message.isMine
                                ? Colors.white
                                : palette.textPrimary,
                            fontSize: Responsive.fontSm,
                          ),
                          mentionStyle: TextStyle(
                            color: message.isMine
                                ? Colors.white
                                : AppColors.brand600,
                            fontSize: Responsive.fontSm,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        4.gapH,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.digits(message.time),
                              style: TextStyle(
                                color: message.isMine
                                    ? Colors.white70
                                    : palette.textMuted,
                                fontSize: Responsive.fontXs,
                              ),
                            ),
                            if (message.isMine) ...[
                              4.gapW,
                              Icon(
                                _statusIcon(message.deliveryStatus),
                                size: 14.sp,
                                color: _statusColor(message.deliveryStatus),
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

IconData _statusIcon(MessageDeliveryStatus status) {
  return switch (status) {
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
