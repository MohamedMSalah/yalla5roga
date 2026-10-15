import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!,
                  style: TextStyle(
                    color: AppColors.brand600,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              if (eyebrow != null) Responsive.spaceXs.gapH,
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontMd,
                ),
              ),
              if (subtitle != null) ...[
                Responsive.spaceXs.gapH,
                Text(
                  subtitle!,
                  style: TextStyle(color: context.palette.textMuted, fontSize: 12.sp),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: TextStyle(
                color: AppColors.brand600,
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontSm,
              ),
            ),
          ),
      ],
    );
  }
}
