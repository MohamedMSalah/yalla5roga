import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_form.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_header.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_tabs.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().resetAuthForm();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final isLogin = auth.isLogin;

    return Scaffold(
      backgroundColor: context.palette.surface,
      body: SafeArea(
        child: ListView(
          padding: Responsive.padding(horizontal: 24, top: 12, bottom: 24),
          children: [
            Row(
              children: [
                AppIconButton(icon: context.chevronBack, onTap: Get.back),
                const Spacer(),
                Icon(Icons.auto_awesome, color: AppColors.brand600, size: 16.w),
                6.gapW,
                Text(
                  l10n.appName,
                  style: TextStyle(
                    color: AppColors.brand600,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontBody,
                  ),
                ),
                const Spacer(),
                SizedBox(width: 40.w),
              ],
            ),
            28.gapH,
            AuthHeader(
              eyebrow: isLogin ? l10n.welcomeBack : l10n.welcomeNew,
              title: isLogin ? l10n.letsGetYouOut : l10n.joinTheFun,
              subtitle: isLogin
                  ? l10n.authLoginSubtitle
                  : l10n.authSignupSubtitle,
            ),
            Responsive.spaceLg.gapH,
            const AuthTabs(),
            Responsive.spaceLg.gapH,
            const AuthForm(),
            Responsive.spaceMd.gapH,
            Text.rich(
              TextSpan(
                text: isLogin ? '${l10n.newHere} ' : '${l10n.alreadyMember} ',
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 12.sp,
                ),
                children: [
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () =>
                          context.read<AuthProvider>().setLogin(!isLogin),
                      child: Text(
                        isLogin ? l10n.createYourAccount : l10n.login,
                        style: TextStyle(
                          color: AppColors.brand600,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
