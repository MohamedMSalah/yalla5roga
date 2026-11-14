import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/special_event_page.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomButton(
          onPressed: () => Get.to(() => const CreateOutingPage()),
          icon: Icons.add,
          label: l10n.newOuting,
        ),
        Responsive.spaceSm.gapH,
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
            final gap = Responsive.spaceSm;
            final width = constraints.maxWidth < 300 || largeText
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: width,
                  child: _SecondaryAction(
                    icon: Icons.celebration_outlined,
                    label: l10n.specialEvent,
                    onPressed: () => Get.to(() => const SpecialEventPage()),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SecondaryAction(
                    icon: Icons.group_add_outlined,
                    label: l10n.newGroup,
                    onPressed: () => Get.to(() => const CreateGroupPage()),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      label: label,
      icon: icon,
      variant: AppButtonVariant.light,
      onPressed: onPressed,
    );
  }
}
