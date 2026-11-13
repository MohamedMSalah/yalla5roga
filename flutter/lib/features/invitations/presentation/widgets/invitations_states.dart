import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';

class InvitationsEmptyState extends StatelessWidget {
  const InvitationsEmptyState({super.key, required this.l10n});
  final L10n l10n;
  @override
  Widget build(BuildContext context) =>
      AppEmptyState(message: l10n.noInvitations, icon: Icons.mail_outline);
}

class InvitationsErrorState extends StatelessWidget {
  const InvitationsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) =>
      AppErrorState(message: message, onRetry: onRetry);
}

class InvitationsSkeleton extends StatelessWidget {
  const InvitationsSkeleton({super.key});
  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView.separated(
      padding: Responsive.pagePadding(),
      itemCount: 3,
      separatorBuilder: (_, _) => Responsive.spaceMd.gapH,
      itemBuilder: (_, _) => ShimmerBone(height: 140.h, radius: 16),
    ),
  );
}
