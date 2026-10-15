import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: AppColors.brand600,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        Responsive.spaceSm.gapH,
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, fontSize: 28.sp),
        ),
        Responsive.spaceSm.gapH,
        Text(
          subtitle,
          style: TextStyle(
            color: context.palette.textMuted,
            height: 1.5,
            fontSize: Responsive.fontBody,
          ),
        ),
      ],
    );
  }
}
