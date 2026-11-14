import 'package:flutter/material.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/create_group_fields.dart';
import 'package:yalla_5roga/features/groups/presentation/widgets/group_invitee_picker.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/pick_device_contacts_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  var _callingCode = '+20';
  var _whatsappOptIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GroupsProvider>().resetCreate();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final path = await ImageSourceSheet.pick(
      title: context.l10n.changeGroupImage,
    );
    if (path == null || !mounted) return;
    context.read<GroupsProvider>().setCreateImage(path);
  }

  Future<void> _pickContacts() async {
    final groups = context.read<GroupsProvider>();
    final selected = await Get.to<List<String>>(
      () => PickDeviceContactsPage(
        initialSelectedPhones: groups.createPhones.toSet(),
        allowInternational: true,
      ),
    );
    if (!mounted || selected == null) return;
    groups.setCreatePhones(selected);
    setState(() => _whatsappOptIn = false);
  }

  bool _addPhone({bool resetConsent = true}) {
    final error = context.read<GroupsProvider>().addCreatePhone(
      Validators.normalizeGroupPhone(
            _phoneController.text,
            callingCode: _callingCode,
          ) ??
          '',
      context.l10n,
    );
    if (error != null) {
      AppSnackBar.show(error);
      return false;
    }
    _phoneController.clear();
    if (resetConsent) setState(() => _whatsappOptIn = false);
    return true;
  }

  void _create() async {
    final groups = context.read<GroupsProvider>();
    if (groups.isCreating) return;
    if (!_whatsappOptIn) return;
    if (!_formKey.currentState!.validate()) return;
    if (_phoneController.text.trim().isNotEmpty &&
        !_addPhone(resetConsent: false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final user = context.read<AuthProvider>().user;
    final l10n = context.l10n;
    final group = await groups.createGroup(
      _nameController.text.trim(),
      ownerName: user?.name ?? l10n.guestFallback,
      ownerAvatar: user?.imageUrl,
      bio: _bioController.text.trim(),
      whatsappOptIn: _whatsappOptIn,
    );
    if (!mounted) return;
    if (group == null) {
      final error = groups.errorMessage;
      if (error != null) AppSnackBar.show(error);
      return;
    }
    AppSnackBar.show(context.l10n.groupCreated);
    Get.off(() => GroupDetailsPage(groupId: group.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = context.watch<GroupsProvider>();
    final image = groups.createImage;
    final phones = groups.createPhones;

    return Scaffold(
      appBar: AppPageBar(title: l10n.createGroup, backIcon: Icons.close),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: groups.isCreating,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: Responsive.pagePadding(),
                        children: [
                          CreateGroupFields(
                            nameController: _nameController,
                            bioController: _bioController,
                            image: image,
                            isCreating: groups.isCreating,
                            onPickImage: _pickImage,
                          ),
                          Responsive.spaceLg.gapH,
                          GroupInviteePicker(
                            phoneController: _phoneController,
                            callingCode: _callingCode,
                            onCallingCodeChanged: (code) => setState(() {
                              _callingCode = code;
                              _whatsappOptIn = false;
                            }),
                            whatsappOptIn: _whatsappOptIn,
                            onWhatsAppOptInChanged: (value) =>
                                setState(() => _whatsappOptIn = value),
                            onPhoneChanged: (_) =>
                                setState(() => _whatsappOptIn = false),
                            phones: phones,
                            isCreating: groups.isCreating,
                            onPickContacts: _pickContacts,
                            onAddPhone: _addPhone,
                            onRemovePhone: (phone) {
                              groups.removeCreatePhone(phone);
                              setState(() => _whatsappOptIn = false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: Responsive.padding(
                    horizontal: 20,
                    top: 8,
                    bottom: 12,
                  ),
                  child: CustomButton(
                    label: l10n.createGroup,
                    icon: Icons.check,
                    isLoading: groups.isCreating,
                    onPressed: _whatsappOptIn ? _create : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
