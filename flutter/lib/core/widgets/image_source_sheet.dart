import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

class ImageSourceSheet {
  const ImageSourceSheet._();

  static Future<String?> pick({required String title}) async {
    final source = await Get.bottomSheet<ImageSource>(
      SafeArea(
        child: Builder(
          builder: (context) {
            final palette = context.palette;
            final l10n = context.l10n;
            // Material (not Container) so ListTile can resolve ink/splash contrast.
            return Material(
              color: palette.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: Responsive.padding(all: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: Responsive.fontMd,
                      ),
                    ),
                    Responsive.spaceMd.gapH,
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.brand50,
                        foregroundColor: AppColors.brand600,
                        child: const Icon(Icons.photo_library_outlined),
                      ),
                      title: Text(
                        l10n.chooseFromGallery,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => Get.back(result: ImageSource.gallery),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.brand50,
                        foregroundColor: AppColors.brand600,
                        child: const Icon(Icons.photo_camera_outlined),
                      ),
                      title: Text(
                        l10n.takePhoto,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => Get.back(result: ImageSource.camera),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );

    if (source == null) return null;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    return file?.path;
  }
}
