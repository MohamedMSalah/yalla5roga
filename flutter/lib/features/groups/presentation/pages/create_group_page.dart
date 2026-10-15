import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/custom_textfield.dart';
import 'package:yalla_5roga/core/widgets/image_source_sheet.dart';
import 'package:yalla_5roga/core/widgets/phone_text_field.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
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

  static const _maxBioLength = 160;

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

  void _addPhone() {
    final error = context.read<GroupsProvider>().addCreatePhone(
      _phoneController.text,
      context.l10n,
    );
    if (error != null) {
      AppSnackBar.show(error);
      return;
    }
    _phoneController.clear();
  }

  void _create() async {
    final groups = context.read<GroupsProvider>();
    if (groups.isCreating) return;
    if (!_formKey.currentState!.validate()) return;
    if (groups.createImage == null && !AppConfig.useMockData) {
      AppSnackBar.show(context.l10n.photoRequired);
      return;
    }
    final user = context.read<AuthProvider>().user;
    final l10n = context.l10n;
    final group = await groups.createGroup(
      _nameController.text.trim(),
      ownerName: user?.name ?? l10n.guestFallback,
      ownerAvatar: user?.imageUrl,
      bio: _bioController.text.trim(),
    );
    if (!mounted || group == null) return;
    AppSnackBar.show(context.l10n.groupCreated);
    Get.off(() => GroupDetailsPage(groupId: group.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final groups = context.watch<GroupsProvider>();
    final image = groups.createImage;
    final phones = groups.createPhones;

    return Scaffold(
      // AppPageBar — create group
      appBar: AppPageBar(title: l10n.createGroup, backIcon: Icons.close),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: Responsive.pagePadding(),
                  children: [
                    GestureDetector(
                      onTap: groups.isCreating ? null : _pickImage,
                      child: image == null
                          ? Container(
                              height: 160.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: palette.surfaceMuted,
                                borderRadius: BorderRadius.circular(22.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.shadow,
                                    blurRadius: 14.w,
                                    offset: Offset(0, 6.h),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppColors.brand600,
                                    size: 28.w,
                                  ),
                                  8.gapH,
                                  Text(
                                    l10n.uploadPhoto,
                                    style: TextStyle(
                                      color: AppColors.brand600,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                AppNetworkImage(
                                  url: image,
                                  width: double.infinity,
                                  height: 160.h,
                                  radius: 22.r,
                                ),
                                Positioned(
                                  right: 12.w,
                                  bottom: 12.h,
                                  child: CircleAvatar(
                                    backgroundColor: AppColors.brand600,
                                    child: Icon(
                                      Icons.camera_alt_outlined,
                                      color: Colors.white,
                                      size: 18.w,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Responsive.spaceLg.gapH,
                    CustomTextField(
                      controller: _nameController,
                      label: l10n.groupName,
                      hint: l10n.groupNameHint,
                      prefixIcon: Icons.groups_2_outlined,
                      inputFormatters: [
                        InputFormatters.maxLength(AppConstants.maxNameLength),
                      ],
                      validator: (value) => Validators.name(value, l10n),
                    ),
                    Responsive.spaceMd.gapH,
                    CustomTextField(
                      controller: _bioController,
                      label: l10n.groupBio,
                      hint: l10n.groupBioHint,
                      prefixIcon: Icons.notes_outlined,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 2,
                      maxLines: 4,
                      inputFormatters: [
                        InputFormatters.maxLength(_maxBioLength),
                      ],
                    ),
                    Responsive.spaceLg.gapH,
                    Text(
                      l10n.addByPhone,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: Responsive.fontSm,
                        color: palette.textSecondary,
                      ),
                    ),
                    Responsive.spaceSm.gapH,
                    PhoneTextField(
                      controller: _phoneController,
                      validate: false,
                    ),
                    Responsive.spaceSm.gapH,
                    CustomButton(
                      label: l10n.addPhone,
                      icon: Icons.person_add_alt_1_outlined,
                      size: AppButtonSize.medium,
                      variant: AppButtonVariant.outlined,
                      onPressed: groups.isCreating ? null : _addPhone,
                    ),
                    if (phones.isNotEmpty) ...[
                      Responsive.spaceMd.gapH,
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          for (final phone in phones)
                            Chip(
                              label: Text(
                                l10n.digits(
                                  MemberDisplayName.resolvePhone(phone),
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.sp,
                                ),
                              ),
                              onDeleted: () => groups.removeCreatePhone(phone),
                              backgroundColor: palette.surfaceMuted,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: Responsive.padding(horizontal: 20, top: 8, bottom: 12),
              child: CustomButton(
                label: l10n.createGroup,
                icon: Icons.check,
                isLoading: groups.isCreating,
                onPressed: _create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
