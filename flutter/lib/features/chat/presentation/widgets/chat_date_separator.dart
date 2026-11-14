import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Expanded(child: Divider(color: context.palette.border)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            DateUtils.isSameDay(date.toLocal(), DateTime.now())
                ? context.l10n.today
                : DateUtils.isSameDay(
                    date.toLocal(),
                    DateTime.now().subtract(const Duration(days: 1)),
                  )
                ? context.l10n.yesterday
                : context.l10n.formatDate(date.toLocal()),
            style: context.texts.labelMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.palette.border)),
      ],
    ),
  );
}
