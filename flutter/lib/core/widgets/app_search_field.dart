import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

/// Search input owns no query state. Callers retain controllers and filtering.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      labelText: hint ?? context.l10n.search,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: onClear == null
          ? null
          : IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
    ),
  );
}
