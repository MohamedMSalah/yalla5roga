import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/presentation/widgets/outing_chat_mention_text.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.name,
    required this.mine,
    required this.members,
    this.grouped = false,
    this.onEdit,
    this.onDelete,
    this.onRetry,
  });
  final ChatMessage message;
  final String name;
  final bool mine, grouped;
  final List<GroupMember> members;
  final VoidCallback? onEdit, onDelete, onRetry;

  Future<void> _actions(BuildContext context) async {
    final editable = onEdit != null && message.canEditAt(DateTime.now());
    final result = await AppBottomSheet.show<String>(
      context: context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.messageOptions, style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(context.l10n.editMessage),
            subtitle: Text(
              editable
                  ? context.l10n.messageEditWindow
                  : context.l10n.messageEditExpired,
            ),
            enabled: editable,
            onTap: editable ? () => Navigator.pop(sheet, 'edit') : null,
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.colors.error),
            title: Text(
              context.l10n.deleteMessage,
              style: TextStyle(color: context.colors.error),
            ),
            onTap: onDelete == null
                ? null
                : () => Navigator.pop(sheet, 'delete'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (result == 'edit') onEdit?.call();
    if (result == 'delete') onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = mine
        ? context.colors.onPrimary
        : context.palette.textPrimary;
    final status = switch (message.deliveryStatus) {
      MessageDeliveryStatus.pending => context.l10n.chatMessagePending,
      MessageDeliveryStatus.failed => context.l10n.chatMessageFailed,
      _ => null,
    };
    final actions = mine && message.text.isNotEmpty && onDelete != null;
    final card = Semantics(
      hint: actions ? context.l10n.messageOptions : null,
      customSemanticsActions: actions
          ? {
              CustomSemanticsAction(label: context.l10n.messageOptions): () =>
                  _actions(context),
            }
          : null,
      child: GestureDetector(
        onLongPress: actions ? () => _actions(context) : null,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppSizes.touchTarget,
            minHeight: AppSizes.touchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.compact,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: mine ? context.colors.primary : context.palette.surfaceMuted,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(AppRadii.card),
              topEnd: const Radius.circular(AppRadii.card),
              bottomStart: Radius.circular(
                mine ? AppRadii.card : AppRadii.small,
              ),
              bottomEnd: Radius.circular(mine ? AppRadii.small : AppRadii.card),
            ),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.text.isEmpty)
                Text(
                  context.l10n.messageDeleted,
                  style: context.texts.bodyMedium?.copyWith(
                    color: foreground,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                OutingChatMentionText(
                  text: message.text,
                  members: members,
                  style: (context.texts.bodyMedium ?? const TextStyle())
                      .copyWith(color: foreground, height: 1.35),
                  mentionStyle: (context.texts.bodyMedium ?? const TextStyle())
                      .copyWith(
                        color: mine ? foreground : context.palette.brandStrong,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                widthFactor: 1,
                heightFactor: 1,
                alignment: mine
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      message.sentAt == null
                          ? context.l10n.formatClock(message.time)
                          : context.l10n.formatTime(message.sentAt!.toLocal()),
                      style: context.texts.labelSmall?.copyWith(
                        color: mine
                            ? foreground
                            : context.palette.textSecondary,
                      ),
                    ),
                    if (mine)
                      Icon(
                        switch (message.deliveryStatus) {
                          MessageDeliveryStatus.pending => Icons.schedule,
                          MessageDeliveryStatus.failed => Icons.error_outline,
                          MessageDeliveryStatus.delivered ||
                          MessageDeliveryStatus.seen => Icons.done_all,
                          _ => Icons.check,
                        },
                        size: 14,
                        color: foreground,
                        semanticLabel: status,
                      ),
                    if (status != null)
                      Text(
                        status,
                        style: context.texts.labelSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                  ],
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(context.l10n.retry),
                ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: grouped ? AppSpacing.xs : AppSpacing.md),
      child: Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: .9,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: mine
                ? (context.isRtl ? TextDirection.ltr : TextDirection.rtl)
                : Directionality.of(context),
            children: [
              if (!grouped)
                UserAvatar(url: message.avatar ?? '', size: 36, enabled: false)
              else
                const SizedBox(width: 36),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!grouped)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          name,
                          style: context.texts.labelMedium?.copyWith(
                            color: context.palette.brandStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    card,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
