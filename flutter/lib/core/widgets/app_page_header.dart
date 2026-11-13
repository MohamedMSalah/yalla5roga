import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// In-content heading; use AppPageBar for routes with back navigation.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: context.texts.headlineSmall),
            ),
            if (subtitle != null) ...[
              Responsive.spaceXs.gapH,
              Text(
                subtitle!,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[Responsive.spaceSm.gapW, trailing!],
    ],
  );
}
