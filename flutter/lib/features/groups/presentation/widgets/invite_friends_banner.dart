import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/groups_style.dart';

class InviteFriendsBanner extends StatelessWidget {
  const InviteFriendsBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final l10n = context.l10n;
    final radius = BorderRadius.circular(GroupsStyle.actionRadius);
    const secondary = Color(0xFFE8D3F9);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: GroupsStyle.banner,
        boxShadow: const [GroupsStyle.actionGlow],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: GroupsStyle.shine,
          border: Border.all(color: const Color(0xFF9452C0)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Semantics(
              button: true,
              enabled: onTap != null,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final largerText =
                      MediaQuery.textScalerOf(context).scale(17) > 21;
                  final narrow = constraints.maxWidth < 330;
                  final planeWidth = math.min(
                    constraints.maxWidth * (largerText || narrow ? .17 : .25),
                    104.0,
                  );
                  return Container(
                    constraints: const BoxConstraints(minHeight: 79),
                    padding: const EdgeInsetsDirectional.fromSTEB(17, 7, 13, 7),
                    child: Row(
                      children: [
                        Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: const Color(0x63221235),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_outlined,
                            color: secondary,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.startNewCircle,
                                style: GroupsStyle.text(
                                  context,
                                  17,
                                  Colors.white,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.inviteFriendsToGroups,
                                style: GroupsStyle.text(
                                  context,
                                  12.5,
                                  secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/groups/paper_plane.svg',
                          width: planeWidth,
                          height: 64,
                          matchTextDirection: true,
                          excludeFromSemantics: true,
                        ),
                        if (onTap != null)
                          Icon(
                            rtl
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            size: 21,
                            color: secondary,
                          ),
                      ],
                    ),
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

class InviteGroupPicker extends StatelessWidget {
  const InviteGroupPicker({super.key, required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .55,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.chooseGroup,
                  style: context.texts.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return ListTile(
                    key: ValueKey(group.id),
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(l10n.digits(group.name)),
                    onTap: () => Navigator.of(context).pop(group.id),
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
