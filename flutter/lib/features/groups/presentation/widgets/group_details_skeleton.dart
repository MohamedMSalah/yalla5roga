import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';

class GroupDetailsSkeleton extends StatelessWidget {
  const GroupDetailsSkeleton({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => GroupPageList(
    children: [
      AppShimmer(
        child: Column(
          children: [
            ShimmerBone(
              width: double.infinity,
              height: compact ? 177 : 206,
              radius: 24,
            ),
            const SizedBox(height: 14),
            ShimmerBone(
              width: double.infinity,
              height: compact ? 76 : 48,
              radius: compact ? 19 : 30,
            ),
            const SizedBox(height: 14),
            ShimmerBone(
              width: double.infinity,
              height: compact ? 104 : 80,
              radius: 19,
            ),
            const SizedBox(height: 14),
            const ShimmerBone(width: double.infinity, height: 124, radius: 19),
            if (compact) ...[
              const SizedBox(height: 14),
              const ShimmerBone(width: double.infinity, height: 92, radius: 19),
            ],
          ],
        ),
      ),
    ],
  );
}
