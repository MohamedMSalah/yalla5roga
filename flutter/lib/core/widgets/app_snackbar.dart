import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yalla_5roga/core/constants/asset_constants.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class AppSnackBar {
  const AppSnackBar._();

  static void show(String message) {
    _present(message, duration: const Duration(milliseconds: 1800));
  }

  /// Longer toast for auth / validation errors so the full message is readable.
  static void showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _present(
      message,
      duration: const Duration(milliseconds: 3600),
      wide: true,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _present(
    String message, {
    required Duration duration,
    bool wide = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    Get.closeCurrentSnackbar();
    Get.showSnackbar(
      GetSnackBar(
        messageText: _ToastBubble(
          message: message,
          wide: wide,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
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
  const _ToastBubble({
    required this.message,
    this.wide = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool wide;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            Responsive.radiusMd,
                          ),
                        ),
                        child: SvgPicture.asset(
                          AssetConstants.logo,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Responsive.spaceSm.gapW,
                      Expanded(
                        child: Text(
                          message,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (actionLabel != null && onAction != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () {
                          Get.closeCurrentSnackbar();
                          onAction!();
                        },
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
