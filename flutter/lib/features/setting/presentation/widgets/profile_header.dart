import 'package:yalla_5roga/features/setting/presentation/widgets/profile_stats.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/illustrated_header.dart';
import 'package:yalla_5roga/core/widgets/app_page_header.dart';
import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IllustratedHeader(
          illustration: HeaderIllustration.cairo,
          height: 90,
          child: AppPageHeader(
            title: l10n.navSettings,
            subtitle: l10n.settingsHeaderBody,
            trailing: IconButton.outlined(
              tooltip: l10n.logOut,
              icon: const Icon(Icons.logout_rounded),
              onPressed: onLogout,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          showBorder: true,
          borderColor: context.palette.brandSoftBorder,
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: context.palette.featureGradient,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: InkWell(
                    onTap: onEditProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Semantics(
                            button: true,
                            label: l10n.editProfile,
                            child: UserAvatar(
                              url: user?.imageUrl ?? '',
                              size: avatar,
                              heroTag: HeroTags.profileAvatar,
                            ),
                          ),
                          Responsive.spaceMd.gapW,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? '',
                                  style: context.texts.titleLarge,
                                ),
                                if (phone.isNotEmpty)
                                  Text(
                                    l10n.digits(phone),
                                    style: context.texts.bodyMedium?.copyWith(
                                      color: context.palette.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            context.chevronForward,
                            color: context.palette.brandStrong,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(),
              const ProfileStats(),
            ],
          ),
        ),
      ],
    );
  }
}
