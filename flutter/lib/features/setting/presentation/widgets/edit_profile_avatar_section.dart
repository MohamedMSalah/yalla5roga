import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';

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
    final avatar = 96.w;

    return Center(
      child: Stack(
        children: [
          Container(
            width: avatar,
            height: avatar,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: context.palette.border, width: 2.w),
            ),
            child: AppNetworkImage.avatar(
              url: imagePath ?? '',
              width: avatar,
              height: avatar,
              radius: 26.r,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: pickEnabled ? onPickImage : null,
              child: CircleAvatar(
                radius: 16.r,
                backgroundColor: AppColors.brand600,
                child: Icon(
                  Icons.edit_outlined,
                  size: 16.w,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
