import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.background,
    this.foreground,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? background;
  final Color? foreground;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            IconCircle(
              icon: icon,
              size: 32,
              radius: 8,
              iconSize: 16,
              background: background ?? context.palette.brandSoft,
              foreground: foreground ?? context.palette.brandStrong,
            ),
            12.gapW,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontBody,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: Responsive.fontSm,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class SettingsChevron extends StatelessWidget {
  const SettingsChevron({super.key});
  @override
  Widget build(BuildContext context) => Icon(
    context.chevronForward,
    color: context.palette.textMuted,
    size: 20.w,
  );
}
