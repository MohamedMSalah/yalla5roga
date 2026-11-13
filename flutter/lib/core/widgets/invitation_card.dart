import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

class InvitationCard extends StatelessWidget {
  const InvitationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.avatar,
    required this.acceptLabel,
    required this.declineLabel,
    this.onAccept,
    this.onDecline,
    this.isAccepting = false,
    this.isDeclining = false,
    this.status,
    this.showActions = true,
  });
  final String title, subtitle, acceptLabel, declineLabel;
  final Widget avatar;
  final VoidCallback? onAccept, onDecline;
  final bool isAccepting, isDeclining;
  final Widget? status;
  final bool showActions;
  @override
  Widget build(BuildContext context) {
    final busy = isAccepting || isDeclining;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              avatar,
              Responsive.spaceSm.gapW,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.texts.titleMedium),
                    Text(
                      subtitle,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status != null) ...[Responsive.spaceSm.gapH, status!],
          if (showActions) ...[
            Responsive.spaceMd.gapH,
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = [
                  CustomButton(
                    label: declineLabel,
                    variant: AppButtonVariant.light,
                    isLoading: isDeclining,
                    onPressed: busy ? null : onDecline,
                  ),
                  CustomButton(
                    label: acceptLabel,
                    isLoading: isAccepting,
                    onPressed: busy ? null : onAccept,
                  ),
                ];
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                  return Column(
                    children: [actions[0], Responsive.spaceSm.gapH, actions[1]],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: actions[0]),
                    Responsive.spaceSm.gapW,
                    Expanded(child: actions[1]),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
