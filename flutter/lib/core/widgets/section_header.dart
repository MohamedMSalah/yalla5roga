import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.eyebrow,
    this.icon,
    this.iconColor,
    this.iconSize = 23,
    this.iconGap = 10,
    this.titleStyle,
    this.trailing,
    this.trailingMaxWidth,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? eyebrow;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize, iconGap;
  final TextStyle? titleStyle;
  final Widget? trailing;
  final double? trailingMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: iconColor ?? context.palette.brandStrong,
            size: iconSize,
          ),
          SizedBox(width: iconGap),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!,
                  style: TextStyle(
                    color: context.palette.brandStrong,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              if (eyebrow != null) Responsive.spaceXs.gapH,
              Semantics(
                header: true,
                child: Text(
                  title,
                  style:
                      titleStyle ??
                      Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (subtitle != null) ...[
                Responsive.spaceXs.gapH,
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          if (trailingMaxWidth case final width?)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: trailing!,
            )
          else
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: trailing!,
              ),
            ),
        ] else if (actionLabel != null)
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: context.palette.brandStrong,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSm,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
