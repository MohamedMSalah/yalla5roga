import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class ProfileEditSheet extends StatelessWidget {
  const ProfileEditSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static Future<T?> show<T>(BuildContext context, WidgetBuilder builder) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: Responsive.pagePadding().add(
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: context.texts.titleLarge),
            Responsive.spaceMd.gapH,
            child,
          ],
        ),
      ),
    );
  }
}
