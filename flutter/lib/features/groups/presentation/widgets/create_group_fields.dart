import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/planning_cover.dart';
import 'package:yalla_5roga/core/widgets/app_text_field.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';

class CreateGroupFields extends StatelessWidget {
  const CreateGroupFields({
    super.key,
    required this.nameController,
    required this.bioController,
    required this.image,
    required this.isCreating,
    required this.onPickImage,
  });
  final TextEditingController nameController, bioController;
  final String? image;
  final bool isCreating;
  final VoidCallback onPickImage;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanningCoverPicker(
          url: image ?? '',
          art: PlanningCoverArt.group,
          optionalLabel: l10n.groupPhotoOptional,
          onTap: isCreating ? null : onPickImage,
        ),
        Responsive.spaceMd.gapH,
        AppTextField(
          controller: nameController,
          label: l10n.groupName,
          hint: l10n.groupNameHint,
          prefixIcon: Icons.groups_2_outlined,
          inputFormatters: [
            InputFormatters.maxLength(AppConstants.maxNameLength),
          ],
          validator: (value) => Validators.name(value, l10n),
        ),
        Responsive.spaceMd.gapH,
        AppTextField(
          controller: bioController,
          label: l10n.groupBio,
          hint: l10n.groupBioHint,
          prefixIcon: Icons.notes_outlined,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 2,
          maxLines: 4,
          inputFormatters: [InputFormatters.maxLength(Group.maxBioLength)],
        ),
      ],
    );
  }
}
