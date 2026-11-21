import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/icon_circle.dart';

/// Centered empty-state: icon above a short message (optional subtitle).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.subtitle,
    this.compact = false,
    this.padding,
  });

  final IconData icon;
  final String message;
  final String? subtitle;

  /// Smaller padding for inline sections inside a scroll view.
  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconCircle(
          icon: icon,
          size: compact ? 56 : 72,
          iconSize: compact ? 26 : 32,
          radius: compact ? 18 : 22,
          background: palette.brandSoft,
          foreground: context.palette.brandStrong,
        ),
        (compact ? 12 : 16).gapH,
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: compact ? Responsive.fontSm : Responsive.fontBody,
            color: palette.textPrimary,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          (compact ? 6 : 8).gapH,
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: compact ? 11.sp : Responsive.fontSm,
              height: 1.35,
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return SizedBox(
        width: double.infinity,
        child: AppCard(
          padding: padding,
          child: Row(
            children: [
              if (MediaQuery.sizeOf(context).width > 230) ...[
                IconCircle(
                  icon: icon,
                  size: 46,
                  iconSize: 22,
                  radius: 15,
                  background: palette.brandSoft,
                  foreground: palette.brandStrong,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, style: context.texts.titleSmall),
                    if (subtitle?.trim().isNotEmpty ?? false)
                      Text(
                        subtitle!,
                        style: context.texts.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final padded = Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: 24.w,
            vertical: compact ? 20.h : 40.h,
          ),
      child: content,
    );

    return Center(child: padded);
  }
}
