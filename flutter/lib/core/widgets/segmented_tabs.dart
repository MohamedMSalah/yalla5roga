import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/theme/app_tokens.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_fade_switcher.dart';

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.children = const [],
    this.badges = const {},
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<Widget> children;
  final Map<int, String> badges;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tabs = Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  inMutuallyExclusiveGroup: true,
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.standard),
                    curve: AppMotion.settle,
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.touchTarget,
                    ),
                    decoration: BoxDecoration(
                      color: i == index ? palette.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: i == index
                          ? [
                              BoxShadow(
                                color: palette.shadow,
                                blurRadius: 8.w,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => onChanged(i),
                        borderRadius: BorderRadius.circular(AppRadii.small.r),
                        child: Padding(
                          padding: Responsive.padding(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: Responsive.spaceXs,
                            runSpacing: Responsive.spaceXs,
                            children: [
                              Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: Responsive.fontSm,
                                  fontWeight: FontWeight.w800,
                                  color: i == index
                                      ? palette.brandStrong
                                      : palette.textMuted,
                                ),
                              ),
                              if (badges[i] != null) ...[
                                Container(
                                  padding: Responsive.padding(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == index
                                        ? palette.brandSoft
                                        : palette.dangerSoft,
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                  child: Text(
                                    badges[i]!,
                                    style: TextStyle(
                                      fontSize: Responsive.fontXs,
                                      fontWeight: FontWeight.w800,
                                      color: i == index
                                          ? palette.brandStrong
                                          : palette.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (children.isEmpty) return tabs;

    final selected = index.clamp(0, children.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabs,
        Responsive.spaceLg.gapH,
        // Body crossfades per tab; the key only changes with the selection so
        // data refreshes inside a tab never replay the reveal.
        AppFadeSwitcher(
          child: KeyedSubtree(
            key: ValueKey(selected),
            child: children[selected],
          ),
        ),
      ],
    );
  }
}
