import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class PhoneVerificationChip extends StatelessWidget {
  const PhoneVerificationChip({
    super.key,
    required this.verified,
    this.onVerify,
  });

  final bool verified;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final background = verified ? AppColors.emerald50 : AppColors.rose50;
    final foreground = verified ? AppColors.emerald500 : AppColors.rose500;

    if (!verified && onVerify != null) {
      return OutlinedButton(
        onPressed: onVerify,
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        child: Text(l10n.verifyPhoneChip),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        verified ? l10n.verified : l10n.notVerified,
        style: TextStyle(
          color: foreground,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
