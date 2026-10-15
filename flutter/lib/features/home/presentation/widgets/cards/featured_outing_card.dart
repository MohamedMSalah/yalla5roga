import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/avatar_stack.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class FeaturedOutingCard extends StatefulWidget {
  const FeaturedOutingCard({super.key});

  @override
  State<FeaturedOutingCard> createState() => _FeaturedOutingCardState();
}

class _FeaturedOutingCardState extends State<FeaturedOutingCard> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = context.watch<OutingsProvider>().outings;
    final index = context.watch<OutingsProvider>().featuredIndex;
    if (slides.isEmpty) {
      return AppEmptyState(
        icon: Icons.photo_outlined,
        message: l10n.noFeaturedOuting,
        subtitle: l10n.noFeaturedOutingHint,
        compact: true,
      );
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: context.palette.shadow,
                blurRadius: 18.w,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            child: SizedBox(
              height: 176.h,
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: context.read<OutingsProvider>().setFeaturedIndex,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return GestureDetector(
                    onTap: () => Get.to(() => EventPage(event: slide)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(
                          url: slide.image,
                          placeholderIcon: Icons.explore_outlined,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xC70F172A)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16.w,
                          top: 16.h,
                          child: Container(
                            padding: Responsive.padding(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12.w,
                                  color: AppColors.brand700,
                                ),
                                6.gapW,
                                Text(
                                  l10n.digits(slide.date),
                                  style: TextStyle(
                                    fontSize: Responsive.fontCaption,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brand700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 16.h,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.nextUp.toUpperCase(),
                                      style: TextStyle(
                                        color: AppColors.brand200,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      slide.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      l10n.digits(slide.meta),
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: Responsive.fontSm,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (slide.going > 0)
                                AvatarStack(
                                  urls: const [],
                                  extra: slide.going.clamp(0, 99),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Responsive.spaceSm.gapH,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: (i == index ? 20 : 6).w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: i == index
                      ? AppColors.brand600
                      : context.palette.border,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
