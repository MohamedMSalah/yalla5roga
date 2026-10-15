import 'package:flutter/material.dart';

class MarqueeText extends StatelessWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 28,
    this.gap = 24,
  });

  final String text;
  final TextStyle? style;
  final double velocity;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
        }
        return _MarqueeBody(
          text: text,
          style: style,
          maxWidth: maxWidth,
          velocity: velocity,
          gap: gap,
        );
      },
    );
  }
}

class _MarqueeBody extends StatefulWidget {
  const _MarqueeBody({
    required this.text,
    required this.style,
    required this.maxWidth,
    required this.velocity,
    required this.gap,
  });

  final String text;
  final TextStyle? style;
  final double maxWidth;
  final double velocity;
  final double gap;

  @override
  State<_MarqueeBody> createState() => _MarqueeBodyState();
}

class _MarqueeBodyState extends State<_MarqueeBody> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _sync();
  }

  @override
  void didUpdateWidget(covariant _MarqueeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.velocity != widget.velocity) {
      _sync();
    }
  }

  TextPainter _painter() {
    return TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
  }

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final width = _painter().width;
      if (!width.isFinite || width <= widget.maxWidth) {
        _controller.stop();
        _controller.value = 0;
        return;
      }
      final distance = width + widget.gap;
      final seconds = (distance / widget.velocity).clamp(4, 20);
      _controller
        ..duration = Duration(milliseconds: (seconds * 1000).round())
        ..repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painter();
    final textWidth = painter.width;
    final height = painter.height;
    if (textWidth <= widget.maxWidth) {
      return SizedBox(
        width: widget.maxWidth,
        height: height,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          textAlign: TextAlign.center,
          style: widget.style,
        ),
      );
    }

    return SizedBox(
      width: widget.maxWidth,
      height: height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final offset = _controller.value * (textWidth + widget.gap);
            final rtl = Directionality.of(context) == TextDirection.rtl;
            final dx = rtl ? offset : -offset;
            final loop = rtl ? -(textWidth + widget.gap) : (textWidth + widget.gap);
            return Stack(
              children: [
                Transform.translate(offset: Offset(dx, 0), child: child),
                Transform.translate(offset: Offset(dx + loop, 0), child: child),
              ],
            );
          },
          child: SizedBox(
            width: textWidth,
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }
}
