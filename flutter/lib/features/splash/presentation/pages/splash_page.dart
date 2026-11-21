import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/asset_constants.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/language_choice.dart';
import 'package:yalla_5roga/core/widgets/app_step_progress.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/auth/presentation/pages/auth_page.dart';

import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_content.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => OnboardingProvider(context.read<SharedPreferences>()),
    child: const _OnboardingPage(),
  );
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage();
  Future<void> _complete(BuildContext context) async {
    final ok = await context.read<OnboardingProvider>().complete();
    if (!context.mounted) return;
    if (ok) {
      Get.offAll(() => const AuthPage());
    } else {
      AppSnackBar.showError(context.l10n.unexpectedError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onboarding = context.watch<OnboardingProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: ListView(
              padding: Responsive.pagePadding(),
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            AssetConstants.logo,
                            width: 40,
                            height: 40,
                            excludeFromSemantics: true,
                          ),
                        ),
                        Responsive.spaceSm.gapW,
                        Text(l10n.appName, style: context.texts.titleLarge),
                      ],
                    ),
                    const LanguageChoice(),
                  ],
                ),
                Responsive.spaceLg.gapH,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: onboarding.busy
                        ? null
                        : () => _complete(context),
                    child: Text(l10n.onboardingSkip),
                  ),
                ),
                OnboardingContent(step: onboarding.step),
                Responsive.spaceXl.gapH,
                AppStepProgress(
                  step: onboarding.step,
                  total: 3,
                  label: '${l10n.n(onboarding.step + 1)} / ${l10n.n(3)}',
                ),
                Responsive.spaceLg.gapH,
                CustomButton(
                  label: onboarding.step == 2
                      ? l10n.getStarted
                      : l10n.onboardingNext,
                  isLoading: onboarding.busy,
                  onPressed: onboarding.busy
                      ? null
                      : onboarding.step == 2
                      ? () => _complete(context)
                      : onboarding.next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
