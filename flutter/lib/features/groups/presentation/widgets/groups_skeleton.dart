import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_style.dart';

class GroupsSkeleton extends StatelessWidget {
  const GroupsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: SliverList.builder(
      addSemanticIndexes: false,
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(top: index == 0 ? 0 : GroupsStyle.gap),
        child: DecoratedBox(
          decoration: GroupsStyle.panel(
            context.palette,
            GroupsStyle.cardRadius,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: GroupsStyle.cardVerticalPadding,
            ),
            child: Row(
              children: [
                ShimmerBone(
                  width: GroupsStyle.imageSize,
                  height: GroupsStyle.imageSize,
                  radius: 16,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: .42,
                        child: ShimmerBone(height: 16),
                      ),
                      SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: .32,
                        child: ShimmerBone(height: 12),
                      ),
                      SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: .69,
                        child: ShimmerBone(height: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
