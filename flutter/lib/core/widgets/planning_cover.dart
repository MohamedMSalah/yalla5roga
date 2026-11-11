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

class PlanningCoverPicker extends StatelessWidget {
  const PlanningCoverPicker({
    super.key,
    required this.url,
    required this.art,
    required this.optionalLabel,
    required this.onTap,
  });

  final String url;
  final PlanningCoverArt art;
  final String optionalLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(22.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: AlignmentDirectional.bottomEnd,
          children: [
            PlanningCover(
              url: url,
              art: art,
              width: double.infinity,
              height: 140.h,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_a_photo_outlined, size: 18),
                      Responsive.spaceSm.gapW,
                      Flexible(
                        child: Text(
                          url.isEmpty
                              ? optionalLabel
                              : context.l10n.changePhoto,
                          style: context.texts.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
