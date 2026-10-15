import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

class GroupInfoActionsSection extends StatelessWidget {
  const GroupInfoActionsSection({
    super.key,
    required this.leaving,
    required this.onLeaveGroup,
  });

  final bool leaving;
  final VoidCallback? onLeaveGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.groupActions,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        Responsive.spaceSm.gapH,
        CustomButton(
          label: l10n.leaveGroup,
          icon: Icons.logout_rounded,
          variant: AppButtonVariant.danger,
          isLoading: leaving,
          onPressed: onLeaveGroup,
        ),
      ],
    );
  }
}
