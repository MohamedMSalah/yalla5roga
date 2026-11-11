import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_card.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group.dart';

class GroupBioCard extends StatefulWidget {
  const GroupBioCard({super.key, required this.bio, this.onSave});

  final String bio;
  final Future<bool> Function(String)? onSave;

  @override
  State<GroupBioCard> createState() => _GroupBioCardState();
}

class _GroupBioCardState extends State<GroupBioCard> {
  final _form = GlobalKey<FormState>();
  final _controller = TextEditingController();
  var _editing = false;
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final onSave = widget.onSave;
    if (_saving || onSave == null || !_form.currentState!.validate()) return;
    final bio = _controller.text.trim();
    if (bio == widget.bio) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    final saved = await onSave(bio);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final isEmpty = widget.bio.trim().isEmpty;
    final canEdit = widget.onSave != null;
    final editing = canEdit && _editing;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.groupBio,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.fontCaption,
                  ),
                ),
              ),
              if (canEdit && !editing)
                TextButton(
                  onPressed: () {
                    _controller.text = widget.bio;
                    setState(() => _editing = true);
                  },
                  child: Text(l10n.editGroupBio),
                ),
            ],
          ),
          6.gapH,
          if (editing)
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _controller,
                    autofocus: true,
                    enabled: !_saving,
                    maxLength: Group.maxBioLength,
                    minLines: 2,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: l10n.groupBio,
                      hintText: l10n.groupBioHint,
                    ),
                    validator: (value) =>
                        (value?.trim().length ?? 0) > Group.maxBioLength
                        ? l10n.groupBioTooLong(Group.maxBioLength)
                        : null,
                  ),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _editing = false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(l10n.saveChanges),
                      ),
                    ],
                  ),
                  if (_saving) const LinearProgressIndicator(),
                ],
              ),
            )
          else
            Text(
              isEmpty ? l10n.noGroupBio : widget.bio,
              style: TextStyle(
                color: isEmpty ? palette.textMuted : palette.textPrimary,
                fontSize: Responsive.fontBody,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
