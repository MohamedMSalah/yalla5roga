import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

/// Floating capsule-shaped bottom navigation bar.
///
/// The entire bar uses a continuous pill-shaped gradient.
/// Selection uses a violet capsule and a filled icon.
/// All existing palette colors, semantics, accessibility, high-contrast
/// handling, and theme responsiveness are preserved.
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
    final highContrast = MediaQuery.highContrastOf(context);

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: Padding(
            // Bottom margin lifts the capsule bar off the bottom edge for the
            // floating effect; horizontal padding keeps it off screen edges.
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _PillBar(
              items: items,
              currentIndex: currentIndex,
              onChanged: onChanged,
              highContrast: highContrast,
            ),
          ),
        ),
      ),
    );
  }
}

/// The inner capsule bar and its hairline outline.
class _PillBar extends StatelessWidget {
  const _PillBar({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.highContrast,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(34),
      side: BorderSide(
        color: highContrast ? palette.textSecondary : palette.border,
        width: 1.0,
      ),
    );

    final barContent = Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: ShapeDecoration(
          shape: shape,
          color: highContrast
              ? palette.navBackground.withValues(alpha: 1)
              : null,
          gradient: highContrast
              ? null
              : LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    palette.surfaceMuted.withValues(alpha: .94),
                    palette.navBackground.withValues(alpha: .96),
                  ],
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 7,
          ),
          child: _NavRow(
            items: items,
            currentIndex: currentIndex,
            onChanged: onChanged,
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: highContrast ? const [] : AppShadows.floating(palette.shadow),
      ),
      child: barContent,
    );
  }
}

/// Equal-width tabs with one shared icon and label baseline.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / items.length;
        final fontSize = slotWidth < 64
            ? AppTypography.compactNavigationLabel
            : AppTypography.navigationLabel;
        final textScaler = MediaQuery.textScalerOf(context);
        final labelStyle = (context.texts.labelSmall ?? const TextStyle())
            .copyWith(
              fontSize: fontSize,
              letterSpacing: 0,
              fontWeight: FontWeight.w500,
              height: 1.2,
            );
        var itemWidth = math.max(slotWidth, AppSizes.touchTarget);
        var labelHeight = 0.0;
        for (final item in items) {
          final painter = TextPainter(
            text: TextSpan(text: item.label, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            locale: Localizations.maybeLocaleOf(context),
            maxLines: 1,
          )..layout();
          // Include the pill border and the label's horizontal inset.
          itemWidth = math.max(itemWidth, painter.width.ceilToDouble() + 6);
          if (painter.height > labelHeight) labelHeight = painter.height;
          painter.dispose();
        }

        final row = Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  item: items[i],
                  selected: i == currentIndex,
                  labelStyle: labelStyle,
                  labelHeight: labelHeight.ceilToDouble(),
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        );
        final scaledUp = textScaler.scale(fontSize) > fontSize;
        final needsScroll =
            slotWidth < AppSizes.touchTarget ||
            (scaledUp && itemWidth > slotWidth);
        if (!needsScroll) return row;
        // Large system text can exceed the available width for five tabs.
        // Let the bar scroll horizontally while preserving the scaled labels.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: itemWidth * items.length, child: row),
        );
      },
    );
  }
}

/// Individual navigation tab item with animated icon and label colors.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.labelStyle,
    required this.labelHeight,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final TextStyle labelStyle;
  final double labelHeight;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.12,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.12,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 1,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    if (widget.selected) _revealSelected();
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.selected) return;
      final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
      final item = context.findRenderObject();
      if (scrollable != null && item != null) {
        scrollable.position.ensureVisible(item, alignment: .5);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (widget.selected) _revealSelected();
    if (widget.selected && !AppMotion.reduce(context)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.standard);
    final highContrast = MediaQuery.highContrastOf(context);
    final palette = context.palette;
    final color = widget.selected
        ? AppPalette.gradientText
        : palette.textSecondary;

    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.item.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: duration,
          constraints: const BoxConstraints(minHeight: AppSizes.navItem),
          decoration: BoxDecoration(
            color: widget.selected && highContrast
                ? const Color(0xFF5022A3)
                : Colors.transparent,
            gradient: widget.selected && !highContrast
                ? (palette.isDark
                      ? AppPalette.darkSelectedGradient
                      : AppPalette.selectedGradient)
                : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.selected && !highContrast
                ? const [BoxShadow(color: Color(0x407B48BD), blurRadius: 9)]
                : const [],
            border: Border.all(
              color: widget.selected
                  ? AppPalette.gradientText.withValues(alpha: .22)
                  : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  tween: ColorTween(begin: color, end: color),
                  builder: (context, value, child) => IconTheme.merge(
                    data: IconThemeData(color: value),
                    child: child!,
                  ),
                  child: SizedBox.square(
                    // Reserve the pulse's full size so it never shifts layout.
                    dimension: AppSizes.navIcon * 1.12,
                    child: Center(
                      child: ScaleTransition(
                        scale: _scale,
                        child: AnimatedSwitcher(
                          duration: duration,
                          switchInCurve: Curves.easeInOutCubic,
                          switchOutCurve: Curves.easeInOutCubic,
                          child: Icon(
                            widget.selected
                                ? widget.item.selectedIcon ?? widget.item.icon
                                : widget.item.icon,
                            key: ValueKey(widget.selected),
                            size: AppSizes.navIcon,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  style: widget.labelStyle.copyWith(color: color),
                  child: SizedBox(
                    height: widget.labelHeight,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: widget.selected && !highContrast ? 1 : 0,
                  duration: duration,
                  child: const SizedBox(
                    height: 2,
                    width: 24,
                    child: ColoredBox(color: AppPalette.selectionHighlight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
