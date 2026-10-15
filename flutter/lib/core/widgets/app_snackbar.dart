import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppSnackBar {
  const AppSnackBar._();

  static void show(String message) {
    _present(message, duration: const Duration(milliseconds: 1800));
  }

  /// Longer toast for auth / validation errors so the full message is readable.
  static void showError(String message) {
    _present(message, duration: const Duration(milliseconds: 3600), wide: true);
  }

  static void _present(
    String message, {
    required Duration duration,
    bool wide = false,
  }) {
    Get.closeCurrentSnackbar();
    Get.showSnackbar(
      GetSnackBar(
        messageText: _ToastBubble(message: message, wide: wide),
        backgroundColor: Colors.transparent,
        snackStyle: SnackStyle.FLOATING,
        margin: Responsive.padding(horizontal: 28, bottom: 28),
        padding: EdgeInsets.zero,
        duration: duration,
        snackPosition: SnackPosition.BOTTOM,
        animationDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({required this.message, this.wide = false});

  final String message;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 320.w : 280.w),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.slate950.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
