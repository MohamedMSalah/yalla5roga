import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_badge.dart';

class OutingCard extends StatelessWidget {
  const OutingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cover,
    this.onTap,
    this.trailing,
    this.statusLabel,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? statusLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final details = Row(
      children: [
        cover,
        AppSpacing.compact.gapW,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.texts.titleMedium),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: AppTypography.caption.sp,
                ),
              ),
              if (statusLabel != null) ...[
                Responsive.spaceXs.gapH,
                AppBadge(
                  label: statusLabel!,
                  color: context.palette.brandSoft,
                  textColor: context.palette.brandStrong,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return AppCard(
      onTap: trailing == null ? onTap : null,
      radius: AppRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: trailing == null || onTap == null
                    ? details
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onTap,
                        child: details,
                      ),
              ),
              if (trailing != null) ...[
                8.gapW,
                trailing!,
              ] else
                Icon(
                  context.chevronForward,
                  color: context.palette.textMuted,
                  size: 20.w,
                ),
            ],
          ),
          if (footer != null) ...[Responsive.spaceSm.gapH, footer!],
        ],
      ),
    );
  }
}
