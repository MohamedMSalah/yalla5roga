import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_hero.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';

/// Circular profile photo used on Home, Settings, and Edit profile.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.url,
    required this.size,
    this.heroTag,
    this.onTap,
    this.enabled = true,
  });

  final String url;
  final double size;
  final String? heroTag;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ring = context.palette.border;
    final image = AppHero(
      tag: heroTag,
      url: url,
      radius: size / 2,
      child: AppNetworkImage.avatar(
        url: url,
        width: size,
        height: size,
        fade: heroTag == null,
      ),
    );

    return AppPressable(
      enabled: enabled,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 2.w),
        ),
        child: image,
      ),
    );
  }
}
