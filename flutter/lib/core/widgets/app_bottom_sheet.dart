import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Shared keyboard-aware, scrollable sheet on the existing Navigator.
abstract final class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.of(context, AppMotion.sheetEnter),
      reverseDuration: AppMotion.of(context, AppMotion.sheetExit),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: Responsive.pagePadding(),
          child: builder(context),
        ),
      ),
    ),
  );
}
