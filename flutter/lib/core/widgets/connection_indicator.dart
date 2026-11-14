import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({
    super.key,
    required this.label,
    required this.connected,
    required this.reconnecting,
  });
  final String label;
  final bool connected;
  final bool reconnecting;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: Responsive.padding(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: connected
            ? AppColors.emerald500.withValues(alpha: .14)
            : context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected
                ? Icons.circle
                : reconnecting
                ? Icons.sync
                : Icons.cloud_off_outlined,
            size: connected ? 8 : 14,
            color: connected
                ? AppColors.emerald500
                : context.palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
