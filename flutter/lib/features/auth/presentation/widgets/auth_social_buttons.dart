import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/pages/main_shell.dart';
import 'package:get/get.dart';

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({super.key});

  Future<void> _handle(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final auth = context.read<AuthProvider>();
    final ok = await action();
    if (!context.mounted) return;
    if (!ok) {
      if (auth.errorCode == 'cancelled') return;
      AppSnackBar.showError(
        context.l10n.authError(
          auth.errorCode,
          fallback: auth.errorMessage ?? context.l10n.loginFailed,
        ),
      );
      return;
    }
    Get.offAll(() => const MainShell());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: palette.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                l10n.orContinueWith,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: Responsive.fontSm,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: palette.border)),
          ],
        ),
        Responsive.spaceMd.gapH,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialIconButton(
              asset: 'assets/branding/google_logo.svg',
              semanticLabel: l10n.continueWithGoogle,
              enabled: !auth.isLoading,
              onTap: () => _handle(context, auth.signInWithGoogle),
            ),
            16.gapW,
            _SocialIconButton(
              asset: 'assets/branding/apple_logo.svg',
              semanticLabel: l10n.continueWithApple,
              enabled: !auth.isLoading,
              invertInDark: true,
              onTap: () => _handle(context, auth.signInWithApple),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.asset,
    required this.semanticLabel,
    required this.onTap,
    required this.enabled,
    this.invertInDark = false,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool enabled;
  final bool invertInDark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = 52.w;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: palette.inputFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: BorderSide(color: palette.border),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14.r),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SvgPicture.asset(
                asset,
                width: 24.w,
                height: 24.w,
                colorFilter: invertInDark && isDark
                    ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
