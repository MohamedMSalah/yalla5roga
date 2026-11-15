import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_form.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_header.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_tabs.dart';
import 'package:yalla_5roga/features/auth/presentation/widgets/auth_scaffold.dart';

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

    return AuthScaffold(
      children: [
        Row(
          children: [
            if (ModalRoute.of(context)?.canPop ?? false)
              AppIconButton(
                icon: context.chevronBack,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: Get.back,
              )
            else
              SizedBox(width: 48.w.clamp(48.0, double.infinity)),
            const Spacer(),
            Icon(
              Icons.auto_awesome,
              color: context.palette.brandStrong,
              size: 16.w,
            ),
            6.gapW,
            Flexible(
              child: Text(
                l10n.appName,
                style: TextStyle(
                  color: context.palette.brandStrong,
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontBody,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(width: 48.w.clamp(48.0, double.infinity)),
          ],
        ),
        28.gapH,
        AuthHeader(
          title: isLogin ? l10n.letsGetYouOut : l10n.joinTheFun,
          subtitle: isLogin ? l10n.authLoginSubtitle : l10n.authSignupSubtitle,
        ),
        Responsive.spaceLg.gapH,
        const AuthTabs(),
        Responsive.spaceLg.gapH,
        const AuthForm(),
        Responsive.spaceMd.gapH,
        TextButton(
          onPressed: auth.isLoading || auth.isAuthenticated
              ? null
              : () => auth.setLogin(!isLogin),
          child: Text(
            isLogin
                ? '${l10n.newHere} ${l10n.createYourAccount}'
                : '${l10n.alreadyMember} ${l10n.login}',
          ),
        ),
      ],
    );
  }
}
