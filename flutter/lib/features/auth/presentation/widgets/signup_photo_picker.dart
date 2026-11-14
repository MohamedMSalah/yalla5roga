import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';

class SignupPhotoPicker extends StatelessWidget {
  const SignupPhotoPicker({super.key, this.path, required this.onPick});
  final String? path;
  final VoidCallback? onPick;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      UserAvatar(
        url: path ?? '',
        size: 80,
        onTap: onPick,
        enabled: onPick != null,
      ),
      TextButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(context.l10n.optionalProfilePhoto),
      ),
    ],
  );
}
