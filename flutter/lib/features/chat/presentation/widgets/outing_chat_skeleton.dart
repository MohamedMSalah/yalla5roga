import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';

class OutingChatSkeleton extends StatelessWidget {
  const OutingChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: Responsive.pagePadding(),
        children: [
          _bubble(mine: false, width: 180.w),
          10.gapH,
          _bubble(mine: true, width: 140.w),
          10.gapH,
          _bubble(mine: false, width: 220.w),
          10.gapH,
          _bubble(mine: true, width: 160.w),
          10.gapH,
          _bubble(mine: false, width: 120.w),
        ],
      ),
    );
  }

  Widget _bubble({required bool mine, required double width}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[ShimmerCircle(size: 28.w), 8.gapW],
          ShimmerBone(width: width, height: 56.h, radius: 16),
        ],
      ),
    );
  }
}

class PlaceSearchSkeleton extends StatelessWidget {
  const PlaceSearchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, _) => 8.gapH,
        itemBuilder: (_, _) => const ShimmerSearchTile(),
      ),
    );
  }
}
