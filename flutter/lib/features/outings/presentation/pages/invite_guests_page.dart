import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';

/// Multi-select contacts for a special event. Returns selected member ids on confirm.
class InviteGuestsPage extends StatefulWidget {
  const InviteGuestsPage({
    super.key,
    required this.contacts,
    this.initialSelectedIds = const {},
  });

  final List<GroupMember> contacts;
  final Set<String> initialSelectedIds;

  @override
  State<InviteGuestsPage> createState() => _InviteGuestsPageState();
}

class _InviteGuestsPageState extends State<InviteGuestsPage> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelectedIds};
  }

  bool get _allSelected =>
      widget.contacts.isNotEmpty && _selected.length == widget.contacts.length;

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(widget.contacts.map((person) => person.id));
      }
    });
  }

  void _confirm() {
    Get.back(result: Set<String>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = context.watch<GroupsProvider>();

    return Scaffold(
      appBar: AppPageBar(
        title: l10n.invitePeople,
        trailing: widget.contacts.isEmpty
            ? null
            : TextButton(
                onPressed: _toggleSelectAll,
                child: Text(
                  _allSelected ? l10n.clearSelection : l10n.selectAll,
                  style: TextStyle(
                    color: AppColors.brand600,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSm,
                  ),
                ),
              ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: widget.contacts.isEmpty
                  ? AppEmptyState(
                      icon: Icons.person_add_alt_1_outlined,
                      message: l10n.invitePeopleHint,
                      compact: true,
                    )
                  : ListView.builder(
                      padding: Responsive.pagePadding(),
                      itemCount: widget.contacts.length,
                      itemBuilder: (context, index) {
                        final person = widget.contacts[index];
                        final selected = _selected.contains(person.id);
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == widget.contacts.length - 1
                                ? 0
                                : 8.h,
                          ),
                          child: AppCard(
                            onTap: () => _toggle(person.id),
                            color: selected ? context.palette.brandSoft : null,
                            child: Row(
                              children: [
                                AppNetworkImage.avatar(
                                  url: person.avatar,
                                  width: 40.w,
                                  height: 40.w,
                                  radius: 12.r,
                                ),
                                12.gapW,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        groups.groupsForMember(person.id),
                                        style: TextStyle(
                                          color: context.palette.textMuted,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: selected,
                                  activeColor: AppColors.brand600,
                                  onChanged: (_) => _toggle(person.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: Responsive.padding(horizontal: 20, top: 8, bottom: 12),
              child: CustomButton(
                label: l10n.confirm,
                icon: Icons.check,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
