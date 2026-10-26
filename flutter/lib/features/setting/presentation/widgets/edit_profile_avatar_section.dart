import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';

class EditProfileAvatarSection extends StatelessWidget {
  const EditProfileAvatarSection({
    super.key,
    required this.imagePath,
    required this.onPickImage,
    required this.pickEnabled,
  });

  final String? imagePath;
  final VoidCallback? onPickImage;
  final bool pickEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final avatar = 104.w;

    return Column(
      children: [
        UserAvatar(
          url: imagePath ?? '',
          size: avatar,
          heroTag: HeroTags.profileAvatar,
          enabled: pickEnabled,
          onTap: onPickImage,
        ),
        Responsive.spaceSm.gapH,
        TextButton.icon(
          onPressed: pickEnabled ? onPickImage : null,
          icon: Icon(
            Icons.camera_alt_outlined,
            size: 16.w,
            color: AppColors.brand600,
          ),
          label: Text(
            l10n.changePhoto,
            style: TextStyle(
              color: AppColors.brand600,
              fontWeight: FontWeight.w800,
              fontSize: Responsive.fontSm,
            ),
          ),
        ),
      ],
    );
  }
}
