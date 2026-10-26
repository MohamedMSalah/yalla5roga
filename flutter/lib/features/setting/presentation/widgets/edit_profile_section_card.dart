import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

class EditProfileSectionCard extends StatelessWidget {
  const EditProfileSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: 4.w, bottom: 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontSm,
                  color: palette.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              if (subtitle != null) ...[
                4.gapH,
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: Responsive.fontCaption,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        AppCard(radius: 20, child: child),
      ],
    );
  }
}
