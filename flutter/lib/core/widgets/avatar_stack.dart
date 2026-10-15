import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.urls,
    this.extra = 0,
    this.size = 28,
  });

  final List<String> urls;
  final int extra;
  final double size;

  @override
  Widget build(BuildContext context) {
    final side = size.w;
    final items = [...urls.take(3), if (extra > 0) '__extra__'];
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: side + (items.length - 1) * (side * 0.62),
      height: side,
      child: Stack(
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: i * (side * 0.62),
              child: items[i] == '__extra__'
                  ? Container(
                      width: side,
                      height: side,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brand600,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.palette.surface,
                          width: 2.w,
                        ),
                      ),
                      child: Text(
                        '+${context.l10n.n(extra)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (size * 0.32).sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : ClipOval(
                      child: AppNetworkImage.avatar(
                        url: items[i],
                        width: side,
                        height: side,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
