import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/create_group_page.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_style.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/create_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/special_event_page.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = [
      QuickActionCard(
        icon: Icons.calendar_today_outlined,
        label: l10n.newOuting,
        colors: QuickActionColors.outing,
        onPressed: () => Get.to(() => const CreateOutingPage()),
      ),
      QuickActionCard(
        icon: Icons.groups_outlined,
        label: l10n.newGroup,
        colors: QuickActionColors.group,
        onPressed: () => Get.to(() => const CreateGroupPage()),
      ),
      QuickActionCard(
        icon: Icons.celebration_outlined,
        label: l10n.specialEvent,
        colors: QuickActionColors.event,
        onPressed: () => Get.to(() => const SpecialEventPage()),
      ),
    ];

    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(HomeStyle.quickActionLabel) >
                19) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: actions,
          );
        }

        return IntrinsicHeight(
          child: Row(
            spacing: gap,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final action in actions) Expanded(child: action)],
          ),
        );
      },
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final QuickActionColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = HomeStyle(context);
    final gradient = style.dark ? colors.dark : colors.light;
    final accent = style.dark ? colors.darkIcon : colors.lightIcon;
    return AppPressable(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: gradient,
            stops: const [0, .49, 1],
          ),
          border: Border.all(
            color: accent.withValues(alpha: style.dark ? .42 : .28),
          ),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (colors == QuickActionColors.outing)
              SizedBox.square(
                dimension: HomeStyle.quickActionIcon,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: HomeStyle.quickActionIcon, color: accent),
                    Positioned(
                      bottom: 4,
                      child: Icon(Icons.add, size: 14, color: accent),
                    ),
                  ],
                ),
              )
            else
              Icon(icon, size: HomeStyle.quickActionIcon, color: accent),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.texts.labelMedium?.copyWith(
                color: style.dark && colors == QuickActionColors.group
                    ? accent
                    : style.text,
                fontSize: HomeStyle.quickActionLabel,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum QuickActionColors {
  outing(
    [Color(0xFF87458F), Color(0xFF492B59), Color(0xFF332567)],
    [Color(0xFFF5D9F5), Color(0xFFF2E0FA), Color(0xFFE3D6FA)],
    Color(0xFFE8B1FB),
    Color(0xFF81349D),
  ),
  group(
    [Color(0xFF365E99), Color(0xFF233858), Color(0xFF252841)],
    [Color(0xFFD5E8FF), Color(0xFFE2EEFC), Color(0xFFE1E5F7)],
    Color(0xFFA7C8FC),
    Color(0xFF315E9C),
  ),
  event(
    [Color(0xFFA46B49), Color(0xFF573646), Color(0xFF43234F)],
    [Color(0xFFFFE1C0), Color(0xFFF7E3EB), Color(0xFFECD9F6)],
    Color(0xFFFFCC82),
    Color(0xFF974724),
  );

  const QuickActionColors(this.dark, this.light, this.darkIcon, this.lightIcon);
  final List<Color> dark, light;
  final Color darkIcon, lightIcon;
}
