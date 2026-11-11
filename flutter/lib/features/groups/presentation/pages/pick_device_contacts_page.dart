import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide PermissionStatus;
import 'package:get/get.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/app_permissions.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';

/// Multi-select phone numbers from the device address book.
/// Returns normalized E.164 phones on confirm.
class PickDeviceContactsPage extends StatefulWidget {
  const PickDeviceContactsPage({
    super.key,
    this.initialSelectedPhones = const {},
    this.allowInternational = false,
  });

  final Set<String> initialSelectedPhones;
  final bool allowInternational;

  @override
  State<PickDeviceContactsPage> createState() => _PickDeviceContactsPageState();
}

class _DeviceContact {
  const _DeviceContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

class _PickDeviceContactsPageState extends State<PickDeviceContactsPage> {
  final _searchController = TextEditingController();
  final _selected = <String>{};
  var _loading = true;
  var _permissionDenied = false;
  var _contacts = <_DeviceContact>[];

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelectedPhones);
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    final result = await AppPermissions.promptContactsAccess(context.l10n);
    if (!mounted) return;
    if (result != AppPermissionResult.granted) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
        _contacts = const [];
      });
      return;
    }

    try {
      final raw = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.name},
      );
      final byPhone = <String, _DeviceContact>{};
      for (final contact in raw) {
        final name = (contact.displayName ?? '').trim();
        for (final phone in contact.phones) {
          final number = (phone.normalizedNumber ?? phone.number).trim();
          final normalized = Validators.normalizeGroupPhone(number);
          if (normalized == null ||
              (!widget.allowInternational && !normalized.startsWith('+20'))) {
            continue;
          }
          byPhone.putIfAbsent(
            normalized,
            () => _DeviceContact(
              name: name.isEmpty ? normalized : name,
              phone: normalized,
            ),
          );
        }
      }
      final items = byPhone.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _contacts = items;
        _loading = false;
      });
      await MemberDisplayName.ensureLoaded(force: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
        _contacts = const [];
      });
    }
  }

  List<_DeviceContact> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return [
      for (final contact in _contacts)
        if (contact.name.toLowerCase().contains(query) ||
            contact.phone.contains(query))
          contact,
    ];
  }

  bool get _allFilteredSelected {
    final items = _filtered;
    return items.isNotEmpty && items.every((c) => _selected.contains(c.phone));
  }

  void _toggle(String phone) {
    setState(() {
      if (!_selected.add(phone)) _selected.remove(phone);
    });
  }

  void _toggleSelectAllFiltered() {
    setState(() {
      final items = _filtered;
      if (_allFilteredSelected) {
        for (final contact in items) {
          _selected.remove(contact.phone);
        }
      } else {
        for (final contact in items) {
          _selected.add(contact.phone);
        }
      }
    });
  }

  void _confirm() {
    Get.back(result: _selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppPageBar(
        title: l10n.selectFromContacts,
        trailing: (!_loading && !_permissionDenied && _contacts.isNotEmpty)
            ? TextButton(
                onPressed: _toggleSelectAllFiltered,
                child: Text(
                  _allFilteredSelected ? l10n.clearSelection : l10n.selectAll,
                  style: TextStyle(
                    color: AppColors.brand600,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSm,
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!_loading && !_permissionDenied) ...[
              Padding(
                padding: Responsive.padding(horizontal: 20, top: 8, bottom: 4),
                child: CustomTextField(
                  controller: _searchController,
                  label: l10n.search,
                  hint: l10n.searchContactsHint,
                  prefixIcon: Icons.search,
                ),
              ),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _permissionDenied
                  ? Center(
                      child: Padding(
                        padding: Responsive.pagePadding(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppEmptyState(
                              icon: Icons.contacts_outlined,
                              message: l10n.contactsOpenSettingsBody,
                              compact: true,
                            ),
                            Responsive.spaceMd.gapH,
                            CustomButton(
                              label: l10n.allowContacts,
                              icon: Icons.contacts_outlined,
                              variant: AppButtonVariant.outlined,
                              onPressed: _load,
                            ),
                          ],
                        ),
                      ),
                    )
                  : filtered.isEmpty
                  ? AppEmptyState(
                      icon: Icons.person_search_outlined,
                      message: l10n.noDeviceContacts,
                      compact: true,
                    )
                  : ListView.builder(
                      padding: Responsive.pagePadding(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final contact = filtered[index];
                        final selected = _selected.contains(contact.phone);
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == filtered.length - 1 ? 0 : 8.h,
                          ),
                          child: AppCard(
                            onTap: () => _toggle(contact.phone),
                            color: selected ? context.palette.brandSoft : null,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: selected
                                      ? AppColors.brand600
                                      : AppColors.brand50,
                                  foregroundColor: selected
                                      ? Colors.white
                                      : AppColors.brand600,
                                  child: Text(
                                    contact.name.isEmpty
                                        ? '?'
                                        : contact.name.characters.first
                                              .toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                12.gapW,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        l10n.digits(contact.phone),
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
                                  onChanged: (_) => _toggle(contact.phone),
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
                label: _selected.isEmpty
                    ? l10n.confirm
                    : l10n.addSelectedContacts(_selected.length),
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
