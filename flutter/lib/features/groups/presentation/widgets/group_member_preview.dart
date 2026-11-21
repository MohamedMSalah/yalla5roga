import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_info_section_card.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_page_chrome.dart';

class GroupMemberPreview extends StatelessWidget {
  const GroupMemberPreview({
    super.key,
    required this.members,
    this.onView,
    this.onInvite,
  });
  final List<GroupMember> members;
  final VoidCallback? onView;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = GroupPageColors(context);
    const diameter = 46.0;
    const gap = 8.0;
    return GroupInfoSectionCard(
      title: l10n.members,
      icon: Icons.people_outline,
      trailing: onInvite == null
          ? null
          : TextButton(
              onPressed: onInvite,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: style.accent,
                minimumSize: const Size(48, 48),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_alt_1, size: 18),
                  const SizedBox(width: 5),
                  Flexible(child: Text(l10n.addPeople)),
                ],
              ),
            ),
      body: Semantics(
        button: onView != null,
        label: l10n.members,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slots =
                      ((constraints.maxWidth + gap) / (diameter + gap))
                          .floor()
                          .clamp(1, 6);
                  final count = members.length > slots
                      ? slots - 1
                      : members.length;
                  return members.isEmpty
                      ? Text(
                          l10n.nothingHere,
                          style: TextStyle(color: style.muted),
                        )
                      : Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final member in members.take(count))
                              UserAvatar(
                                key: ValueKey(member.id),
                                url: member.avatar,
                                size: diameter,
                              ),
                            if (members.length > count)
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: diameter,
                                  minHeight: diameter,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: style.iconSurface,
                                  border: Border.all(color: style.border),
                                  borderRadius: BorderRadius.circular(diameter),
                                ),
                                alignment: Alignment.center,
                                width: diameter,
                                child: Text(
                                  '+${l10n.n(members.length - count)}',
                                  textAlign: TextAlign.center,
                                  style: context.texts.labelMedium?.copyWith(
                                    color: style.accent,
                                  ),
                                ),
                              ),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
