import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';

class OutingChatMentionPicker extends StatelessWidget {
  const OutingChatMentionPicker({
    super.key,
    required this.members,
    required this.showMentionAll,
    required this.mentionAllLabel,
    required this.mentionAllSubtitle,
    required this.onSelected,
    required this.onMentionAll,
    required this.title,
    required this.emptyLabel,
  });

  final List<GroupMember> members;
  final bool showMentionAll;
  final String mentionAllLabel;
  final String mentionAllSubtitle;
  final ValueChanged<GroupMember> onSelected;
  final VoidCallback onMentionAll;
  final String title;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final itemCount = members.length + (showMentionAll ? 1 : 0);
    return Material(
      color: palette.surface,
      elevation: 2,
      child: Container(
        constraints: BoxConstraints(maxHeight: 220.h),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: Responsive.padding(horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.sp,
                  color: palette.textMuted,
                ),
              ),
            ),
            if (itemCount == 0)
              Padding(
                padding: Responsive.padding(horizontal: 16, vertical: 12),
                child: Text(
                  emptyLabel,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: Responsive.fontSm,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: 8.h),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (showMentionAll && index == 0) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18.r,
                              backgroundColor: AppColors.brand50,
                              child: Icon(
                                Icons.groups_outlined,
                                color: AppColors.brand600,
                                size: 18.sp,
                              ),
                            ),
                            title: Text(
                              mentionAllLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: Responsive.fontSm,
                                color: AppColors.brand600,
                              ),
                            ),
                            subtitle: Text(
                              mentionAllSubtitle,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: palette.textMuted,
                              ),
                            ),
                            onTap: onMentionAll,
                          ),
                          if (itemCount > 1)
                            Divider(height: 1, color: palette.border),
                        ],
                      );
                    }
                    final member = members[index - (showMentionAll ? 1 : 0)];
                    final name = MemberDisplayName.resolve(member);
                    final isLast = index == itemCount - 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          dense: true,
                          leading: AppNetworkImage.avatar(
                            url: member.avatar,
                            width: 36.w,
                            height: 36.w,
                            radius: 999,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.fontSm,
                            ),
                          ),
                          onTap: () => onSelected(member),
                        ),
                        if (!isLast) Divider(height: 1, color: palette.border),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
