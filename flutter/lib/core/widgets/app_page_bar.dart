import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';

class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = true,
    this.backIcon = Icons.arrow_back,
    this.onBack,
    this.trailingIcon,
    this.onTrailingTap,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final bool showBack;
  final IconData backIcon;
  final VoidCallback? onBack;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final Widget? trailing;

  static const _barHeight = 64.0;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? _barHeight : _barHeight + 12);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final slot = SizedBox(width: 40.w);
    final trailingWidget = trailing ??
        (trailingIcon == null || onTrailingTap == null
            ? null
            : AppIconButton(icon: trailingIcon!, onTap: onTrailingTap!));

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: Responsive.padding(horizontal: 20, top: 8, bottom: 8),
        child: Row(
          children: [
            if (showBack)
              AppIconButton(
                icon: backIcon,
                onTap: onBack ?? Get.back,
              )
            else
              slot,
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: Responsive.fontMd),
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted, fontSize: 10.sp),
                    ),
                ],
              ),
            ),
            trailingWidget ?? slot,
          ],
        ),
      ),
    );
  }
}
