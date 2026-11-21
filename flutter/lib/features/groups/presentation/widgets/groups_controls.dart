import 'package:yalla_5roga/core/widgets/gradient_action_button.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/theme/app_palette.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_style.dart';

class GroupsHeader extends StatelessWidget {
  const GroupsHeader({super.key, this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final artWidth = math.min(constraints.maxWidth * .52, 220.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              end: 0,
              bottom: -13,
              width: artWidth,
              child: IgnorePointer(
                child: SvgPicture.asset(
                  'assets/groups/header_people.svg',
                  excludeFromSemantics: true,
                  matchTextDirection: true,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  9,
                  16,
                  stacked ? 54 : artWidth - 2,
                  stacked ? 61 : 5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        context.l10n.groupsTitle,
                        style: GroupsStyle.text(
                          context,
                          30,
                          palette.textPrimary,
                          weight: FontWeight.w800,
                          height: 1.14,
                        ),
                      ),
                    ),
                    if (summary != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        summary!,
                        style: GroupsStyle.text(
                          context,
                          13.5,
                          palette.textSecondary,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const PositionedDirectional(
              top: 0,
              end: 0,
              child: NotificationButton(showUnreadDot: true),
            ),
          ],
        );
      },
    );
  }
}

class CreateGroupButton extends StatelessWidget {
  const CreateGroupButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GradientActionButton(
      label: context.l10n.newGroup,
      icon: Icons.add_rounded,
      onTap: onTap,
      gradient: GroupsStyle.action,
      highlight: GroupsStyle.shine,
      glow: GroupsStyle.actionGlow,
      borderColor: const Color(0xFFB889EF),
      radius: GroupsStyle.actionRadius,
      height: 48,
      iconGap: 10,
      textStyle: GroupsStyle.text(
        context,
        18,
        Colors.white,
        weight: FontWeight.w600,
      ),
    );
  }
}

class GroupSearchBar extends StatefulWidget {
  const GroupSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
  });

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<GroupSearchBar> createState() => _GroupSearchBarState();
}

class _GroupSearchBarState extends State<GroupSearchBar> {
  late final _controller = TextEditingController(text: widget.query);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant GroupSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.query) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    const noBorder = InputBorder.none;
    return Stack(
      children: [
        Positioned.fill(
          top: 2,
          bottom: 2,
          child: DecoratedBox(decoration: GroupsStyle.panel(palette, 19)),
        ),
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          style: GroupsStyle.text(context, 14, palette.textPrimary),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.searchGroups,
            hintStyle: GroupsStyle.text(context, 14, palette.hint),
            contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 10, 16, 10),
            filled: false,
            border: noBorder,
            enabledBorder: noBorder,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: palette.brandSoftBorder),
            ),
            prefixIconConstraints: const BoxConstraints.tightFor(width: 49),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 22,
              color: palette.textSecondary,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            suffixIcon: widget.query.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.clearGroupSearch,
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: palette.textSecondary,
                    ),
                  ),
            constraints: const BoxConstraints(minHeight: 48),
          ),
        ),
      ],
    );
  }
}

class GroupsFilterBar extends StatelessWidget {
  const GroupsFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final GroupsFilter selected;
  final ValueChanged<GroupsFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = [
      (GroupsFilter.all, l10n.allGroups, null),
      (
        GroupsFilter.mostActive,
        l10n.mostActive,
        Icons.local_fire_department_outlined,
      ),
      (
        GroupsFilter.recentlyCreated,
        l10n.recentlyCreatedGroups,
        Icons.calendar_month_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              for (final (option, label, icon) in options)
                GroupFilterChip(
                  label: label,
                  icon: icon,
                  selected: option == selected,
                  onTap: () => onSelected(option),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupFilterChip extends StatelessWidget {
  const GroupFilterChip({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const radius = BorderRadius.all(Radius.circular(999));
    final foreground = selected ? Colors.white : palette.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              top: 5,
              bottom: 5,
              child: AnimatedContainer(
                duration: AppMotion.reduce(context)
                    ? Duration.zero
                    : AppMotion.press,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: selected
                      ? (palette.isDark
                            ? GroupsStyle.selected
                            : AppPalette.selectedGradient)
                      : palette.panelGradient,
                  border: Border.all(
                    color: selected ? const Color(0xFFAA6CEE) : palette.border,
                  ),
                  boxShadow: selected
                      ? const [GroupsStyle.actionGlow]
                      : const [],
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 17, color: foreground),
                          const SizedBox(width: 7),
                        ],
                        Text(
                          label,
                          style: GroupsStyle.text(
                            context,
                            12.5,
                            foreground,
                            weight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
