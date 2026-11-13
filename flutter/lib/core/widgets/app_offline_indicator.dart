import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Opt-in local connection status. Does not subscribe or alter sync behavior.
class AppOfflineIndicator extends StatelessWidget {
  const AppOfflineIndicator({super.key, required this.isOffline, this.message});
  final bool isOffline;
  final String? message;
  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: Responsive.padding(all: AppSpacing.compact),
        decoration: BoxDecoration(
          color: context.palette.warningSoft,
          borderRadius: BorderRadius.circular(AppRadii.control.r),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: context.palette.warning),
            Responsive.spaceSm.gapW,
            Expanded(
              child: Text(
                message ?? context.l10n.offlineStatus,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.palette.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
