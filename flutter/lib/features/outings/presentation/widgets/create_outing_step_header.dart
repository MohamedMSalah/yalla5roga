import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/gradient_action_button.dart';

class OutingCreationStyle {
  const OutingCreationStyle(this.context);
  final BuildContext context;

  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get ink => dark ? const Color(0xFFFAF7FF) : context.palette.textPrimary;
  Color get muted =>
      dark ? const Color(0xFFB9AAD5) : context.palette.textSecondary;
  Color get accent =>
      dark ? const Color(0xFFCB9AFB) : context.palette.brandStrong;
  Color get active =>
      dark ? const Color(0xFFB461FA) : context.palette.brandStrong;
  Color get border => dark ? const Color(0xFF3E3057) : context.palette.border;
  Color get track => dark ? const Color(0xFF514465) : const Color(0xFFE3D8F0);
  Color get base => dark ? const Color(0xFF100D1C) : context.palette.background;
  Color get panel => dark ? const Color(0xFF161224) : context.palette.surface;
  Color get field => dark ? const Color(0xFF1C162B) : context.palette.surface;
  Color get elevated =>
      dark ? const Color(0xFF251A3A) : context.palette.brandSoft;

  BoxDecoration surface({double radius = 18, bool raised = false}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [raised ? elevated : field, field],
        ),
        border: Border.all(
          color: dark ? border.withValues(alpha: .58) : border,
        ),
      );

  static const activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9138E5), Color(0xFF7023CD), Color(0xFF5317AB)],
  );
}

class OutingCreationBackground extends StatelessWidget {
  const OutingCreationBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    if (!style.dark) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [style.elevated, style.base],
          ),
        ),
        child: child,
      );
    }
    return ColoredBox(
      color: style.base,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-1.06, -1.04),
            radius: 1.05,
            colors: [Color(0xFF201631), Color(0x00161122)],
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.07, -1.12),
              radius: 1.13,
              colors: [Color(0xFF1E152D), Color(0x00161122)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class OutingCreationAppBar extends StatelessWidget {
  const OutingCreationAppBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onInfo,
  });

  final String title;
  final VoidCallback? onBack, onInfo;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(
        children: [
          CreationIconButton(
            icon: context.chevronBack,
            tooltip: context.l10n.back,
            onPressed: onBack,
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.texts.titleLarge?.copyWith(
                  color: style.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            tooltip: context.l10n.creationInfo,
            color: style.muted,
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline_rounded, size: 24),
          ),
        ],
      ),
    );
  }
}

class CreateOutingStepHeader extends StatelessWidget {
  const CreateOutingStepHeader({
    super.key,
    required this.details,
    required this.onLocation,
  });

  final bool details;
  final VoidCallback? onLocation;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth * .25;
          return Stack(
            children: [
              PositionedDirectional(
                start: cell / 2 + 19,
                end: cell / 2 + 19,
                top: 15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: ColoredBox(
                    color: style.track,
                    child: FractionallySizedBox(
                      widthFactor: details ? 1 : .11,
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        height: 2.5,
                        child: ColoredBox(color: style.active),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: cell,
                    child: _Step(
                      number: 1,
                      label: l10n.wizardLocation,
                      current: !details,
                      completed: details,
                      onTap: details ? onLocation : null,
                    ),
                  ),
                  SizedBox(
                    width: cell,
                    child: _Step(
                      number: 2,
                      label: l10n.wizardDetailsShort,
                      current: details,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.label,
    required this.current,
    this.completed = false,
    this.onTap,
  });

  final int number;
  final String label;
  final bool current, completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    final active = current || completed;
    return Semantics(
      selected: current,
      label: '${context.l10n.stepOf(number, 2)} · $label',
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              children: [
                const SizedBox(height: 3),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? null : style.track,
                    gradient: active
                        ? OutingCreationStyle.activeGradient
                        : null,
                    border: Border.all(
                      color: active ? style.active : Colors.transparent,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 26,
                    child: Center(
                      child: completed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                context.l10n.n(number),
                                style: TextStyle(
                                  color: active || style.dark
                                      ? Colors.white
                                      : style.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? style.active : style.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class CreationSectionHeading extends StatelessWidget {
  const CreationSectionHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: style.dark
                  ? const [Color(0xFF3B1C65), Color(0xFF291247)]
                  : [style.elevated, style.field],
            ),
            border: Border.all(color: style.border),
          ),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 25, color: style.accent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.texts.titleLarge?.copyWith(
                    fontSize: 19,
                    color: style.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: context.texts.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  color: style.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CreationIconButton extends StatelessWidget {
  const CreationIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 42,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: style.surface(radius: 13),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          tooltip: tooltip,
          onPressed: onPressed,
          color: style.muted,
          icon: Icon(icon, size: 23),
        ),
      ],
    );
  }
}

class CreationPrimaryButton extends StatelessWidget {
  const CreationPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.trailing = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading, trailing;

  @override
  Widget build(BuildContext context) {
    final style = OutingCreationStyle(context);
    final enabled = onPressed != null || loading;
    final foreground = enabled ? Colors.white : style.muted;
    return GradientActionButton(
      label: label,
      icon: icon,
      onTap: onPressed,
      loading: loading,
      iconTrailing: trailing,
      iconColor: foreground,
      iconGap: 10,
      iconSize: 22,
      radius: 32,
      height: 48,
      borderColor: enabled ? const Color(0xFFAA64F2) : style.border,
      gradient: enabled
          ? OutingCreationStyle.activeGradient
          : LinearGradient(colors: [style.field, style.panel]),
      highlight: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x16FFFFFF), Colors.transparent],
      ),
      glow: enabled
          ? const BoxShadow(
              color: Color(0x4D080411),
              offset: Offset(0, 3),
              blurRadius: 8,
            )
          : null,
      textStyle: context.texts.titleMedium?.copyWith(
        color: foreground,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
