import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/constants/asset_constants.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/features/auth/presentation/pages/auth_page.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/language_choice.dart';
import 'package:yalla_5roga/features/splash/presentation/widgets/splash_preview.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.brand600,
      body: Stack(
        children: [
          Positioned(
            left: -90.w,
            top: 70.h,
            child: _blob(const Color(0xFFA78BFA)),
          ),
          Positioned(
            right: -70.w,
            bottom: 180.h,
            child: _blob(Colors.white.withValues(alpha: 0.12)),
          ),
          SafeArea(
            child: Padding(
              padding: Responsive.padding(horizontal: 24, top: 12, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: SvgPicture.asset(
                          AssetConstants.logo,
                          width: 20.w,
                          height: 20.w,
                        ),
                      ),
                      Responsive.spaceSm.gapW,
                      Text(
                        l10n.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18.sp,
                        ),
                      ),

                      const Spacer(),

                      // LanguageChoice — English / العربية (same as Settings)
                      const LanguageChoice(onBrand: true),
                    ],
                  ),
                  28.gapH,
                  // SplashPreview — decorative marketing card
                  const SplashPreview(),
                  const Spacer(),
                  Container(
                    padding: Responsive.padding(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      l10n.plansMadeSimple.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.brand100,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  12.gapH,
                  Text(
                    '${l10n.splashHeadline1}\n${l10n.splashHeadline2}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.fontXl,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  12.gapH,
                  Text(
                    l10n.splashBody,
                    style: TextStyle(
                      color: AppColors.brand100,
                      height: 1.5,
                      fontSize: Responsive.fontBody,
                    ),
                  ),
                  Responsive.spaceLg.gapH,
                  // CustomButton — Get started → AuthPage
                  CustomButton(
                    label: l10n.getStarted,
                    icon: Icons.arrow_forward,
                    variant: AppButtonVariant.light,
                    onPressed: () {
                      Get.to(() => const AuthPage());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color) {
    return Container(
      width: 220.w,
      height: 220.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.28),
      ),
    );
  }
}
