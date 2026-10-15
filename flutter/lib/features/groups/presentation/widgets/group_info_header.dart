import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/group_bio_card.dart';

class GroupInfoHeader extends StatelessWidget {
  const GroupInfoHeader({
    super.key,
    required this.group,
    required this.outingCount,
    required this.canManage,
    required this.onChangeImage,
  });

  final Group group;
  final int outingCount;
  final bool canManage;
  final VoidCallback? onChangeImage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final headerHeight = (MediaQuery.sizeOf(context).width * 0.42).clamp(
      150.0,
      220.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: canManage ? onChangeImage : null,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AppNetworkImage(
                url: group.image,
                width: double.infinity,
                height: headerHeight,
                radius: 22.r,
                placeholderIcon: Icons.groups_outlined,
              ),
              if (canManage)
                Positioned(
                  right: 12.w,
                  bottom: 12.h,
                  child: CircleAvatar(
                    backgroundColor: AppColors.brand600,
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 18.w,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Responsive.spaceMd.gapH,
        Text(
          group.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontLg,
          ),
        ),
        6.gapH,
        Text(
          l10n.membersOutings(group.memberCount, outingCount),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: Responsive.fontSm,
          ),
        ),
        Responsive.spaceSm.gapH,
        GroupBioCard(bio: group.bio),
      ],
    );
  }
}
