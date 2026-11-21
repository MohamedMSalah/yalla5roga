import 'package:yalla_5roga/core/widgets/section_header.dart';
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
    this.canInvite = false,
  });

  final List<GroupMember> members;
  final bool canManage;
  final bool canInvite;
  final VoidCallback onAddMember;
  final void Function(GroupMember member) onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.members,
          icon: Icons.people_outline,
          actionLabel: canInvite ? l10n.addPeople : null,
          onAction: canInvite ? onAddMember : null,
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
