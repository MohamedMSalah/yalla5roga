import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

class AppAlert {
  const AppAlert._();

  static Future<bool> confirm({
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool destructive = false,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        content: Text(message, style: TextStyle(fontSize: Responsive.fontBody)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            children: [
              CustomButton(
                label: confirmText,
                variant: destructive
                    ? AppButtonVariant.danger
                    : AppButtonVariant.filled,
                onPressed: () => Get.back(result: true),
              ),
              Responsive.spaceSm.gapH,
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(
                  cancelText,
                  style: TextStyle(
                    color: Get.context?.palette.textMuted ?? AppColors.slate500,
                    fontSize: Responsive.fontBody,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      barrierDismissible: true,
    );
    return result ?? false;
  }

  static Future<void> info({
    required String title,
    required String message,
    required String okText,
  }) {
    return Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontMd,
          ),
        ),
        content: Text(message, style: TextStyle(fontSize: Responsive.fontBody)),
        actions: [CustomButton(label: okText, onPressed: Get.back)],
      ),
    );
  }

  /// Connection-error dialog with a wifi-off icon above the warning copy.
  static Future<void> networkError({
    required String title,
    required String message,
    required String okText,
  }) {
    if (Get.isDialogOpen == true) return Future.value();

    final palette = Get.context?.palette;
    return Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        contentPadding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 8.h),
        actionsPadding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 20.h),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48.r,
              color: palette?.textMuted ?? AppColors.slate500,
            ),
            16.gapH,
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: Responsive.fontMd,
                color: palette?.textPrimary ?? AppColors.slate900,
              ),
            ),
            8.gapH,
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.fontBody,
                color: palette?.textMuted ?? AppColors.slate500,
                height: 1.35,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [CustomButton(label: okText, onPressed: Get.back)],
      ),
      barrierDismissible: true,
    );
  }
}
