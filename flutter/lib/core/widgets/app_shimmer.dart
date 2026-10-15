import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';

/// Sliding highlight shared by every [ShimmerBone] under this widget.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _ShimmerScope(percent: _controller.value, child: child!);
      },
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.percent, required super.child});

  final double percent;

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
            ?.percent ??
        0.5;
  }

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      percent != oldWidget.percent;
}

class _ShimmerSlide extends GradientTransform {
  const _ShimmerSlide(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
  }
}

/// Grey placeholder block that mirrors a photo, label, or chip.
class ShimmerBone extends StatelessWidget {
  const ShimmerBone({
    super.key,
    this.width,
    this.height,
    this.radius,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double? radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = palette.surfaceMuted;
    final highlight = Color.lerp(base, palette.surface, 0.72)!;
    final percent = _ShimmerScope.of(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular((radius ?? 8).r),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [base, highlight, base],
          stops: const [0.1, 0.5, 0.9],
          transform: _ShimmerSlide(percent),
        ),
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShimmerBone(width: size, height: size, shape: BoxShape.circle);
  }
}

class ShimmerLine extends StatelessWidget {
  const ShimmerLine({super.key, this.width, this.height, this.radius = 6});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerBone(width: width, height: height ?? 10.h, radius: radius);
  }
}

class ShimmerIconButton extends StatelessWidget {
  const ShimmerIconButton({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShimmerBone(width: size.w, height: size.w, radius: 12);
  }
}

class ShimmerChipRow extends StatelessWidget {
  const ShimmerChipRow({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) Responsive.spaceSm.gapW,
          ShimmerBone(width: (i == 0 ? 72 : 96).w, height: 32.h, radius: 999),
        ],
      ],
    );
  }
}

class ShimmerTabs extends StatelessWidget {
  const ShimmerTabs({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: context.palette.surfaceSoft,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
                child: Center(
                  child: ShimmerLine(width: 56.w, height: 12.h),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ShimmerSectionHeader extends StatelessWidget {
  const ShimmerSectionHeader({
    super.key,
    this.eyebrow = false,
    this.action = false,
    this.wideTitle = false,
  });

  final bool eyebrow;
  final bool action;
  final bool wideTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow) ...[
                ShimmerLine(width: 88.w, height: 8.h),
                Responsive.spaceXs.gapH,
              ],
              ShimmerLine(width: (wideTitle ? 160 : 120).w, height: 16.h),
              Responsive.spaceXs.gapH,
              ShimmerLine(width: (wideTitle ? 200 : 150).w, height: 10.h),
            ],
          ),
        ),
        if (action) ShimmerLine(width: 48.w, height: 12.h),
      ],
    );
  }
}

class ShimmerOutingTile extends StatelessWidget {
  const ShimmerOutingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      child: Row(
        children: [
          ShimmerBone(width: 48.w, height: 48.w, radius: 12),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(width: 140.w, height: 12.h),
                Responsive.spaceXs.gapH,
                ShimmerLine(width: 180.w, height: 9.h),
              ],
            ),
          ),
          ShimmerBone(width: 16.w, height: 16.w, radius: 4),
        ],
      ),
    );
  }
}

class ShimmerPlaceTile extends StatelessWidget {
  const ShimmerPlaceTile({super.key});

  @override
  Widget build(BuildContext context) {
    final thumb = Responsive.avatarLg * 0.62;
    return AppCard(
      radius: 18,
      child: Row(
        children: [
          ShimmerBone(width: thumb, height: thumb, radius: 14),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(width: 120.w, height: 12.h),
                Responsive.spaceXs.gapH,
                ShimmerLine(width: 80.w, height: 9.h),
              ],
            ),
          ),
          ShimmerBone(width: 52.w, height: 22.h, radius: 999),
        ],
      ),
    );
  }
}

class ShimmerDiscoverCard extends StatelessWidget {
  const ShimmerDiscoverCard({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact
        ? (Responsive.isMobile ? 210.w : 240.w)
        : (Responsive.isMobile ? 260.w : 300.w);
    final height = compact ? 196.h : 236.h;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(Responsive.radiusLg),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 18.w,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Responsive.radiusLg),
              ),
              child: const ShimmerBone(
                width: double.infinity,
                height: double.infinity,
                radius: 0,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 10.w : 12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(width: width * 0.7, height: 10.h),
                if (!compact) ...[
                  Responsive.spaceXs.gapH,
                  ShimmerLine(width: width * 0.9, height: 9.h),
                ],
                Responsive.spaceSm.gapH,
                ShimmerLine(width: 88.w, height: 11.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerDiscoverStrip extends StatelessWidget {
  const ShimmerDiscoverStrip({
    super.key,
    this.compact = true,
    this.count = 3,
    this.showHeader = false,
  });

  final bool compact;
  final int count;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[const ShimmerSectionHeader(action: true), 12.gapH],
        SizedBox(
          height: compact ? 196.h : 236.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            separatorBuilder: (_, _) => Responsive.spaceSm.gapW,
            itemBuilder: (_, _) => ShimmerDiscoverCard(compact: compact),
          ),
        ),
      ],
    );
  }
}

/// Vertical stack of place-tile placeholders (no section title).
class ShimmerPlaceList extends StatelessWidget {
  const ShimmerPlaceList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) Responsive.spaceSm.gapH,
          const ShimmerPlaceTile(),
        ],
      ],
    );
  }
}

/// Vertical stack of outing-tile placeholders (no section title).
class ShimmerOutingList extends StatelessWidget {
  const ShimmerOutingList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) 8.gapH,
          const ShimmerOutingTile(),
        ],
      ],
    );
  }
}

class ShimmerNotificationCard extends StatelessWidget {
  const ShimmerNotificationCard({super.key, this.unread = false});

  final bool unread;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      color: unread ? context.palette.brandSoft : context.palette.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBone(width: 44.w, height: 44.w, radius: 12),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(width: double.infinity, height: 11.h),
                6.gapH,
                ShimmerLine(width: 180.w, height: 11.h),
                Responsive.spaceSm.gapH,
                Row(
                  children: [
                    ShimmerLine(width: 64.w, height: 9.h),
                    const Spacer(),
                    if (unread)
                      ShimmerBone(width: 64.w, height: 28.h, radius: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerGroupCard extends StatelessWidget {
  const ShimmerGroupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          ShimmerBone(width: 56.w, height: 56.w, radius: 16),
          12.gapW,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(width: 140.w, height: 13.h),
                Responsive.spaceXs.gapH,
                ShimmerLine(width: 110.w, height: 9.h),
                6.gapH,
                ShimmerLine(width: double.infinity, height: 11.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerFeaturedGroup extends StatelessWidget {
  const ShimmerFeaturedGroup({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Responsive.radiusLg),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.spaceMd),
            color: context.palette.surfaceMuted,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBone(width: 72.w, height: 20.h, radius: 999),
                      Responsive.spaceSm.gapH,
                      ShimmerLine(width: 160.w, height: 16.h),
                      Responsive.spaceXs.gapH,
                      ShimmerLine(width: 100.w, height: 9.h),
                    ],
                  ),
                ),
                ShimmerCircle(size: 36.w),
              ],
            ),
          ),
          Container(
            color: context.palette.surface,
            padding: EdgeInsets.all(14.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLine(width: 90.w, height: 9.h),
                          Responsive.spaceXs.gapH,
                          ShimmerLine(width: 150.w, height: 13.h),
                        ],
                      ),
                    ),
                    ShimmerBone(width: 56.w, height: 22.h, radius: 999),
                  ],
                ),
                12.gapH,
                Row(
                  children: [
                    Expanded(child: ShimmerBone(height: 40.h, radius: 12)),
                    Responsive.spaceSm.gapW,
                    const ShimmerIconButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for the Groups active-vote carousel card.
class ShimmerVoteCard extends StatelessWidget {
  const ShimmerVoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Responsive.voteCardWidth,
      height: double.infinity,
      child: AppCard(
        padding: Responsive.padding(all: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLine(width: 72.w, height: Responsive.fontSm),
            Responsive.spaceXs.gapH,
            Row(
              children: [
                ShimmerBone(width: 36.w, height: 36.w, radius: 14),
                Responsive.spaceSm.gapW,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLine(
                        width: double.infinity,
                        height: Responsive.fontBody,
                      ),
                      ShimmerLine(width: 64.w, height: Responsive.fontCaption),
                    ],
                  ),
                ),
              ],
            ),
            Responsive.spaceXs.gapH,
            ShimmerLine(width: 110.w, height: Responsive.fontCaption),
            Responsive.spaceXs.gapH,
            Row(
              children: [
                ShimmerBone(
                  width: 64.w,
                  height: Responsive.fontCaption + 10.h,
                  radius: 999,
                ),
                Responsive.spaceXs.gapW,
                Expanded(
                  child: ShimmerLine(
                    width: double.infinity,
                    height: Responsive.fontCaption,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ShimmerBone(width: double.infinity, height: 40.h, radius: 12),
          ],
        ),
      ),
    );
  }
}

class ShimmerSearchTile extends StatelessWidget {
  const ShimmerSearchTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShimmerBone(width: 24.w, height: 24.w, radius: 6),
        16.gapW,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLine(width: 180.w, height: 12.h),
              Responsive.spaceXs.gapH,
              ShimmerLine(width: 120.w, height: 9.h),
            ],
          ),
        ),
      ],
    );
  }
}
