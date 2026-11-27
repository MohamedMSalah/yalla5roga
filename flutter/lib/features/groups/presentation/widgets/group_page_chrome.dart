import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/gradient_action_button.dart';

class GroupPageColors {
  GroupPageColors(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark,
      text = context.palette.textPrimary,
      lightMuted = context.palette.textSecondary,
      lightAccent = context.palette.brandStrong,
      lightBorder = context.palette.brandSoftBorder;

  final bool dark;
  final Color text, lightMuted, lightAccent, lightBorder;

  Color get muted => dark ? const Color(0xFFBBA6D9) : lightMuted;
  Color get accent => dark ? const Color(0xFFCEA0FF) : lightAccent;
  Color get border => dark ? const Color(0xFF3C2D50) : lightBorder;
  Color get iconSurface =>
      dark ? const Color(0xFF251A35) : const Color(0xFFF0E6FB);
  List<Color> get card => dark
      ? const [Color(0xFF281C39), Color(0xFF20172D)]
      : const [Color(0xFFFCF8FF), Color(0xFFF3E9FC)];
}

class GroupPageBackground extends StatelessWidget {
  const GroupPageBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = GroupPageColors(context).dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-.55, -.9),
          radius: 1.1,
          colors: dark
              ? const [Color(0xFF291941), Color(0xFF191226), Color(0xFF100D17)]
              : const [Color(0xFFECDBFB), Color(0xFFF5EDFC), Color(0xFFFAF7FD)],
          stops: const [0, .45, 1],
        ),
      ),
      child: child,
    );
  }
}

class GroupPageMenuAction {
  const GroupPageMenuAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class GroupPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GroupPageAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<GroupPageMenuAction> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final style = GroupPageColors(context);
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: style.iconSurface,
      foregroundColor: style.dark ? const Color(0xFFE7D7FF) : style.accent,
      side: BorderSide(color: style.border),
      minimumSize: const Size.square(44),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: IconButton(
                    style: buttonStyle,
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: Get.back,
                    icon: const BackButtonIcon(),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleLarge?.copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: style.text,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: actions.isEmpty
                      ? null
                      : PopupMenuButton<GroupPageMenuAction>(
                          tooltip: MaterialLocalizations.of(context)
                              .showMenuTooltip,
                          icon: const Icon(Icons.more_vert, size: 22),
                          style: buttonStyle,
                          onSelected: (action) => action.onTap(),
                          itemBuilder: (_) => [
                            for (final action in actions)
                              PopupMenuItem(
                                value: action,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(action.icon),
                                  title: Text(action.label),
                                ),
                              ),
                          ],
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

class GroupPageList extends StatelessWidget {
  const GroupPageList({super.key, required this.children, this.physics});
  final List<Widget> children;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
        child: SingleChildScrollView(
          physics: physics,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class GroupSurface extends StatelessWidget {
  const GroupSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = GroupPageColors(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(19),
      side: BorderSide(color: style.border),
    );
    return Material(
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.card,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class GroupActionButton extends StatelessWidget {
  const GroupActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.destructive = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive, loading;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? const Color(0xFF53172E)
        : const Color(0xFF26143F);
    return GradientActionButton(
      label: label,
      icon: icon,
      iconColor: foreground,
      iconSize: destructive ? 22 : 24,
      onTap: onTap,
      loading: loading,
      gradient: LinearGradient(
        colors: destructive
            ? const [Color(0xFFF55D97), Color(0xFFEB6197), Color(0xFFF46FA4)]
            : const [Color(0xFFE2CDFC), Color(0xFFD4B9F9), Color(0xFFCBB0F5)],
      ),
      highlight: const LinearGradient(
        colors: [Color(0x14FFFFFF), Colors.transparent],
      ),
      borderColor: const Color(0x66FFFFFF),
      textStyle: context.texts.titleMedium?.copyWith(
        color: foreground,
        fontSize: destructive ? 15 : 17,
        fontWeight: FontWeight.w700,
      ),
      radius: 32,
      height: 48,
    );
  }
}
