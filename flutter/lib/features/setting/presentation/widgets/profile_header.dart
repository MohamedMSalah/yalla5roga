import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onEditProfile,
  });

  final User? user;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final avatar = Responsive.avatarLg;
    final phone = (user?.phone ?? '').trim();

    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppIconButton(
            icon: Icons.logout,
            background: Colors.white.withValues(alpha: 0.16),
            foreground: Colors.white,
            onTap: onLogout,
          ),
        ),
        UserAvatar(
          url: user?.imageUrl ?? '',
          size: avatar,
          heroTag: HeroTags.profileAvatar,
          onTap: onEditProfile,
        ),
        12.gapH,
        Text(
          user?.name ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (phone.isNotEmpty) ...[
          4.gapH,
          Text(
            l10n.digits(phone),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.brand100,
              fontSize: Responsive.fontSm,
            ),
          ),
        ],
        Responsive.spaceMd.gapH,
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEditProfile,
            borderRadius: BorderRadius.circular(999.r),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
                child: Text(
                  l10n.editProfile,
                  style: TextStyle(
                    color: AppColors.brand100,
                    fontSize: Responsive.fontSm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
