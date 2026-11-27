import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.palette.isDark;
    final background = dark ? const Color(0xFF12101B) : const Color(0xFFFAF7FD);
    final upperBackground = dark
        ? const Color(0xFF191526)
        : const Color(0xFFF1E7FA);
    final glow = dark ? const Color(0xFF53328C) : const Color(0xFFDCC3F4);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [upperBackground, background, background],
          stops: const [0, .56, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            height: 285,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const AlignmentDirectional(.44, -.35),
                    radius: .58,
                    colors: [glow, glow.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
