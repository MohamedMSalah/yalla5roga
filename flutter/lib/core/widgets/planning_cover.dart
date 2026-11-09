import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';

enum PlanningCoverArt { group, outing, birthday, wedding }

class PlanningCover extends StatelessWidget {
  const PlanningCover({
    super.key,
    required this.url,
    required this.art,
    required this.width,
    required this.height,
    this.radius,
  });

  final String url;
  final PlanningCoverArt art;
  final double width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppNetworkImage(
      url: url,
      width: width,
      height: height,
      radius: radius,
      fade: false,
      placeholder: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: palette.brandSoft,
          child: Padding(
            padding: EdgeInsets.all((height * .09).clamp(3, 14).toDouble()),
            child: SvgPicture.asset(
              'assets/covers/${art.name}.svg',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(
                palette.brandStrong,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
