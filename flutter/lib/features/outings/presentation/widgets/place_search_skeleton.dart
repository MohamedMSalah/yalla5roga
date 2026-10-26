import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';

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
