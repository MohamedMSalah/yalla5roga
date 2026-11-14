import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.closed,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.chatClosedLabel,
    required this.chatClosedHint,
    required this.onSend,
    this.busy = false,
    this.onCancelEdit,
    this.onMention,
  });
  final bool closed, busy;
  final VoidCallback? onCancelEdit, onMention;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText, chatClosedLabel, chatClosedHint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.sheet),
      ),
      boxShadow: AppShadows.card(context.palette.shadow),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: Responsive.padding(horizontal: 12, vertical: 10),
        child: closed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: context.palette.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          chatClosedLabel,
                          style: context.texts.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    chatClosedHint,
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCancelEdit != null)
                    Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: context.palette.brandStrong,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            context.l10n.editMessage,
                            style: context.texts.labelLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.cancel,
                          onPressed: onCancelEdit,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 2000,
                            textInputAction: TextInputAction.newline,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => currentLength > 1800
                                ? Text(
                                    context.l10n.digits(
                                      '$currentLength/$maxLength',
                                    ),
                                  )
                                : null,
                            decoration: InputDecoration(
                              hintText: hintText,
                              filled: true,
                              fillColor: context.palette.background,
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                    16,
                                    12,
                                    4,
                                    12,
                                  ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                                borderSide: BorderSide(
                                  color: context.palette.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                                borderSide: BorderSide(
                                  color: context.palette.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                                borderSide: BorderSide(
                                  color: context.colors.primary,
                                  width: 2,
                                ),
                              ),
                              suffixIcon: IconButton(
                                tooltip: context.l10n.mentionSomeone,
                                onPressed: onMention,
                                icon: Icon(
                                  Icons.alternate_email,
                                  color: context.palette.brandStrong,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: value.text.length > 1800 ? 24 : 0,
                          ),
                          child: IconButton.filled(
                            tooltip: onCancelEdit == null
                                ? context.l10n.sendMessage
                                : context.l10n.saveChanges,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(
                                AppSizes.touchTarget,
                                AppSizes.touchTarget,
                              ),
                              shape: const CircleBorder(),
                            ),
                            onPressed: busy || value.text.trim().isEmpty
                                ? null
                                : onSend,
                            icon: busy
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.palette.textSecondary,
                                    ),
                                  )
                                : Icon(
                                    onCancelEdit == null
                                        ? Icons.send_rounded
                                        : Icons.check_rounded,
                                    textDirection: Directionality.of(context),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

typedef OutingChatComposer = MessageComposer;
