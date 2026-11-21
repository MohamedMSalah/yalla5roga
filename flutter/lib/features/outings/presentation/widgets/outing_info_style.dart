import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Surface and accent colors scoped to Outing Info.
class OutingInfoStyle {
  const OutingInfoStyle(this.context);
  final BuildContext context;

  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get text =>
      dark ? const Color(0xFFFAF8FC) : context.palette.textPrimary;
  Color get secondary =>
      dark ? const Color(0xFFC0B9CC) : context.palette.textSecondary;
  Color get icon =>
      dark ? const Color(0xFFDED2F1) : context.palette.brandStrong;
  Color get accent => dark ? const Color(0xFFC76BF1) : context.palette.brand;
  Color get border => dark ? const Color(0xFF38313F) : context.palette.border;
  Color get control =>
      dark ? const Color(0xFF201B28) : context.palette.brandSoft;
  Color get success => dark ? const Color(0xFF89DCC0) : context.palette.success;
  Color get warning => dark ? const Color(0xFFFFCF77) : context.palette.warning;
  Color get danger => dark ? const Color(0xFFF58AAE) : context.palette.danger;

  Gradient get background => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: dark
        ? const [Color(0xFF16121C), Color(0xFF131117), Color(0xFF100E14)]
        : [
            context.palette.brandSoft,
            context.palette.background,
            context.palette.background,
          ],
    stops: const [0, .29, 1],
  );

  Gradient get card => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: dark
        ? const [Color(0xFF241D2D), Color(0xFF1A1821)]
        : [context.palette.surface, context.palette.surfaceSoft],
  );

  static const purple = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF602C91), Color(0xFF411D73)],
  );

  TextStyle type(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) => Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: size,
    height: 1.25,
    fontWeight: weight,
    color: color ?? text,
  );
}

class OutingInfoPanel extends StatelessWidget {
  const OutingInfoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(13),
    this.radius = 16,
    this.outline,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? outline;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = OutingInfoStyle(context);
    final corners = BorderRadius.circular(radius);
    return Material(
      color: Colors.transparent,
      borderRadius: corners,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient ?? style.card,
          borderRadius: corners,
          border: Border.all(color: outline ?? style.border),
        ),
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}
