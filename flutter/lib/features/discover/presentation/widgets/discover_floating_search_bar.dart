import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';

class DiscoverFloatingSearchBar extends StatelessWidget {
  const DiscoverFloatingSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: palette.border),
    );
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: context.texts.bodyLarge?.copyWith(
                color: palette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.discoverSearchHint,
                hintStyle: TextStyle(color: palette.hint),
                filled: true,
                fillColor: palette.inputFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                constraints: const BoxConstraints(minHeight: 52),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: BorderSide(color: palette.brandStrong),
                ),
                prefixIconColor: palette.textSecondary,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        color: palette.textSecondary,
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const NotificationButton(showUnreadDot: true, size: 52),
      ],
    );
  }
}
