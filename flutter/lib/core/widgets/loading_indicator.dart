import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/responsive/responsive.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 28,
    this.strokeWidth = 3,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.w,
      height: size.w,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth.w,
        color: color,
      ),
    );
  }
}
