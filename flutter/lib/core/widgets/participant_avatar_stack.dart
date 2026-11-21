import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';

class ParticipantAvatarStack extends StatelessWidget {
  const ParticipantAvatarStack({
    super.key,
    required this.urls,
    required this.extra,
    required this.ring,
    required this.counterFill,
    required this.counterText,
    this.size = 24,
    this.fallbackFill,
    this.verifiedIndexes = const {},
  });

  final List<String> urls;
  final int extra;
  final Color ring, counterFill, counterText;
  final double size;
  final Color? fallbackFill;
  final Set<int> verifiedIndexes;

  @override
  Widget build(BuildContext context) {
    final step = size * .75;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (urls.isNotEmpty)
          SizedBox(
            width: size + (urls.length - 1) * step,
            height: size,
            child: Stack(
              children: [
                for (var i = 0; i < urls.length; i++)
                  PositionedDirectional(
                    start: i * step,
                    child: Stack(
                      children: [
                        DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: ring),
                          ),
                          child: ClipOval(
                            child: AppNetworkImage(
                              url: urls[i],
                              width: size,
                              height: size,
                              fade: false,
                              placeholderIcon: Icons.person_rounded,
                              placeholderColor:
                                  fallbackFill ?? context.palette.brandSoft,
                              placeholderIconColor: fallbackFill == null
                                  ? context.palette.brandStrong
                                  : Colors.white,
                            ),
                          ),
                        ),
                        if (verifiedIndexes.contains(i))
                          const PositionedDirectional(
                            bottom: 0,
                            end: 0,
                            child: CircleAvatar(
                              radius: 6,
                              backgroundColor: Color(0xFF207558),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (extra > 0) ...[
          if (urls.isNotEmpty) const SizedBox(width: 3),
          Flexible(
            child: Container(
              constraints: BoxConstraints(minWidth: size, minHeight: size),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              decoration: BoxDecoration(
                color: counterFill,
                borderRadius: BorderRadius.circular(size),
              ),
              child: Text(
                '+${context.l10n.n(extra)}',
                textAlign: TextAlign.center,
                style: context.texts.labelSmall?.copyWith(
                  color: counterText,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
