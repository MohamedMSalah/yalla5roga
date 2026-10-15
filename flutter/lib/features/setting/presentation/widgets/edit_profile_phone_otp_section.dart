import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/otp_input.dart';

class EditProfilePhoneOtpSection extends StatelessWidget {
  const EditProfilePhoneOtpSection({
    super.key,
    required this.phoneChanged,
    required this.otpSent,
    required this.phoneAutoVerified,
    required this.isLoading,
    required this.otpController,
    required this.onSendOtp,
  });

  final bool phoneChanged;
  final bool otpSent;
  final bool phoneAutoVerified;
  final bool isLoading;
  final TextEditingController otpController;
  final VoidCallback onSendOtp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: phoneChanged
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Responsive.spaceMd.gapH,
                if (phoneAutoVerified)
                  Text(
                    l10n.phoneVerified,
                    style: TextStyle(
                      color: AppColors.brand700,
                      fontWeight: FontWeight.w800,
                      fontSize: Responsive.fontSm,
                    ),
                  )
                else if (otpSent)
                  OtpInput(
                    controller: otpController,
                    label: l10n.otp,
                    length: Validators.otpLength,
                    validator: (value) => Validators.otp(value, l10n),
                    action: TextButton(
                      onPressed: isLoading ? null : onSendOtp,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.resendOtp,
                        style: TextStyle(
                          color: AppColors.brand600,
                          fontSize: Responsive.fontSm,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  CustomButton(
                    label: l10n.sendOtp,
                    icon: Icons.sms_outlined,
                    variant: AppButtonVariant.outlined,
                    isLoading: isLoading,
                    onPressed: onSendOtp,
                  ),
              ],
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
