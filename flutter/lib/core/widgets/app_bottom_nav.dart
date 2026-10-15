import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: Responsive.navHeight,
      decoration: BoxDecoration(
        color: palette.navBackground,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: Responsive.padding(horizontal: 12, top: 8, bottom: 10),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(14.r),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: Responsive.padding(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: i == currentIndex ? palette.brandSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        items[i].icon,
                        size: Responsive.iconMd,
                        color: i == currentIndex ? AppColors.brand600 : palette.textMuted,
                      ),
                    ),
                    Responsive.spaceXs.gapH,
                    Text(
                      items[i].label,
                      style: TextStyle(
                        fontSize: Responsive.fontCaption,
                        fontWeight: FontWeight.w800,
                        color: i == currentIndex ? AppColors.brand600 : palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
