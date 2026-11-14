import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

import 'sign_out_to_login.dart';

Future<void> confirmDeleteAccount(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  if (auth.isLoading) return;
  final l10n = context.l10n;
  final confirmed = await AppAlert.confirm(
    title: l10n.deleteAccountTitle,
    message: l10n.deleteAccountBody,
    confirmText: l10n.deleteAccount,
    cancelText: l10n.cancel,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  if (await auth.deleteAccount() && context.mounted) {
    await signOutToLogin(context);
  }
}
