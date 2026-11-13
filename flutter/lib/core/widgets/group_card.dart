import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cover,
    this.onTap,
    this.description,
  });
  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback? onTap;
  final String? description;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        cover,
        Responsive.spaceSm.gapW,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.texts.titleMedium),
              if (description?.trim().isNotEmpty == true)
                Text(
                  description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodyMedium,
                ),
              Text(
                subtitle,
                style: context.texts.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ],
          ),
        ),
        Icon(context.chevronForward, color: context.palette.textMuted),
      ],
    ),
  );
}
