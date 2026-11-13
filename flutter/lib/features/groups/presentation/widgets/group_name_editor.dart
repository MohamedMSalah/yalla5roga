import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/core/widgets/app_text_field.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';

class GroupNameEditor extends StatefulWidget {
  const GroupNameEditor({super.key, required this.name, required this.onSave});
  final String name;
  final Future<bool> Function(String) onSave;
  @override
  State<GroupNameEditor> createState() => _GroupNameEditorState();
}

class _GroupNameEditorState extends State<GroupNameEditor> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.name);
  bool _saving = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = await widget.onSave(_controller.text.trim());
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: AppTextField(
            controller: _controller,
            label: context.l10n.groupName,
            validator: (value) => Validators.name(value, context.l10n),
            inputFormatters: [
              InputFormatters.maxLength(AppConstants.maxNameLength),
            ],
          ),
        ),
        Responsive.spaceLg.gapH,
        CustomButton(
          label: context.l10n.saveChanges,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    ),
  );
}
