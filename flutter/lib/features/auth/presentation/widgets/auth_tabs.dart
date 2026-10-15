import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/segmented_tabs.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

class AuthTabs extends StatelessWidget {
  const AuthTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    return SegmentedTabs(
      labels: [l10n.login, l10n.register],
      index: auth.isLogin ? 0 : 1,
      onChanged: (index) => context.read<AuthProvider>().setLogin(index == 0),
    );
  }
}
