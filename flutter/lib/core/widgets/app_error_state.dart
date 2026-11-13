import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: Responsive.pagePadding(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEmptyState(
            message: message,
            icon: Icons.error_outline_rounded,
            compact: true,
          ),
          if (onRetry != null)
            CustomButton(
              label: context.l10n.retry,
              onPressed: onRetry,
              expand: false,
            ),
        ],
      ),
    ),
  );
}
