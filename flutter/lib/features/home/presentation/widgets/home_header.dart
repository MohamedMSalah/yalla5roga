import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/app_pressable.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/home/presentation/widgets/home_style.dart';
import 'package:yalla_5roga/features/setting/presentation/pages/edit_profile_page.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = HomeStyle(context);
    final (name, photo) = context.select(
      (AuthProvider p) => (p.user?.name, p.user?.imageUrl),
    );

    return Stack(
      children: [
        PositionedDirectional(
          bottom: 0,
          start: 0,
          end: 0,
          height: 91,
          child: const CairoSkylineIllustration(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 4, 17, 49),
          child: Row(
            children: [
              Tooltip(
                message: l10n.editProfile,
                child: Semantics(
                  label: l10n.editProfile,
                  child: AppPressable(
                    onTap: name == null
                        ? null
                        : () => Get.to(() => const EditProfilePage()),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: style.avatarRing),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: style.avatar,
                            ),
                            child: AppNetworkImage(
                              url: photo ?? '',
                              width: 42,
                              height: 42,
                              radius: 21,
                              placeholder: Icon(
                                Icons.person_rounded,
                                color: style.accent,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.greetingForHour(DateTime.now().hour),
                      style: context.texts.bodySmall?.copyWith(
                        fontSize: HomeStyle.greeting,
                        color: style.muted,
                      ),
                    ),
                    Text(
                      name?.trim().split(RegExp(r'\s+')).first ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.headlineLarge?.copyWith(
                        fontSize: HomeStyle.userName,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                        color: style.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const NotificationButton(showUnreadDot: true),
            ],
          ),
        ),
      ],
    );
  }
}

class CairoSkylineIllustration extends StatelessWidget {
  const CairoSkylineIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SvgPicture.asset(
        'assets/home/cairo_skyline.svg',
        fit: BoxFit.fitHeight,
        alignment: AlignmentDirectional.bottomEnd,
        matchTextDirection: true,
        excludeFromSemantics: true,
      ),
    );
  }
}
