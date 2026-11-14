import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/special_event_page.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final actions = [
      _QuickAction(
        icon: Icons.event_available_outlined,
        label: l10n.newOuting,
        foreground: palette.outingAction,
        background: palette.outingActionSoft,
        onPressed: () => Get.to(() => const CreateOutingPage()),
      ),
      _QuickAction(
        icon: Icons.groups_outlined,
        label: l10n.newGroup,
        foreground: palette.groupAction,
        background: palette.groupActionSoft,
        onPressed: () => Get.to(() => const CreateGroupPage()),
      ),
      _QuickAction(
        icon: Icons.celebration_outlined,
        label: l10n.specialEvent,
        foreground: palette.eventAction,
        background: palette.eventActionSoft,
        onPressed: () => Get.to(() => const SpecialEventPage()),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = Responsive.spaceSm;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (constraints.maxWidth < 260 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                actions[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: Responsive.padding(horizontal: 4, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 30, color: foreground),
                  AppSpacing.sm.gapH,
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.texts.labelSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
