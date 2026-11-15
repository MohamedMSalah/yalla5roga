import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

class OutingScheduleField extends StatelessWidget {
  const OutingScheduleField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: context.palette.textSecondary,
          ),
        ),
        Responsive.spaceSm.gapH,
        Row(
          children: [
            Icon(icon, size: 16, color: context.palette.brandStrong),
            Responsive.spaceSm.gapW,
            Expanded(
              child: Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
