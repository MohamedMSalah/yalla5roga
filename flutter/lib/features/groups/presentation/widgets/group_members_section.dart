import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/cards/group_member_card.dart';

class GroupMembersSection extends StatelessWidget {
  const GroupMembersSection({
    super.key,
    required this.members,
    required this.canManage,
    required this.onAddMember,
    required this.onRemoveMember,
  });

  final List<GroupMember> members;
  final bool canManage;
  final VoidCallback onAddMember;
  final void Function(GroupMember member) onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.members,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.fontMd,
                ),
              ),
            ),
            if (canManage)
              TextButton.icon(
                onPressed: onAddMember,
                icon: Icon(Icons.person_add_alt_1_outlined, size: 18.w),
                label: Text(l10n.addPeople),
              ),
          ],
        ),
        Responsive.spaceSm.gapH,
        if (members.isEmpty)
          AppEmptyState(
            icon: Icons.person_off_outlined,
            message: l10n.nothingHere,
            compact: true,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final person = members[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == members.length - 1 ? 0 : 8.h,
                ),
                child: GroupMemberCard(
                  member: person,
                  canManage: canManage,
                  onRemove: () => onRemoveMember(person),
                ),
              );
            },
          ),
      ],
    );
  }
}
