import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';

class OutingChatComposer extends StatelessWidget {
  const OutingChatComposer({
    super.key,
    required this.closed,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.chatClosedLabel,
    required this.chatClosedHint,
    required this.onSend,
  });

  final bool closed;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String chatClosedLabel;
  final String chatClosedHint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      top: false,
      child: Padding(
        padding: Responsive.padding(horizontal: 16, top: 8, bottom: 8),
        child: closed
            ? Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 10.w,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18.w,
                          color: palette.textMuted,
                        ),
                        8.gapW,
                        Text(
                          chatClosedLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                    4.gapH,
                    Text(
                      chatClosedHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: hintText,
                        filled: true,
                        fillColor: palette.inputFill,
                      ),
                    ),
                  ),
                  8.gapW,
                  AppIconButton(
                    icon: Icons.send_rounded,
                    background: AppColors.brand600,
                    foreground: Colors.white,
                    onTap: onSend,
                  ),
                ],
              ),
      ),
    );
  }
}
