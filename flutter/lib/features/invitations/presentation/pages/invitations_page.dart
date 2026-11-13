import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/responsive/responsive.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invitations/domain/entities/group_invitation.dart';
import 'package:yalla_5roga/features/invitations/presentation/providers/invitations_provider.dart';
import 'package:yalla_5roga/features/shell/presentation/providers/shell_provider.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvitationsProvider>().loadInvitations();
    });
  }

  Future<void> _accept(GroupInvitation invitation) async {
    final l10n = context.l10n;
    final provider = context.read<InvitationsProvider>();
    final groups = context.read<GroupsProvider>();
    final shell = context.read<ShellProvider>();

    final success = await provider.acceptInvitation(invitation.invitationId);
    if (success && mounted) {
      provider.onInvitationAccepted(invitation.invitationId);
      AppSnackBar.show(l10n.invitationAccepted(invitation.groupName));
      // Refresh groups so the newly joined group appears in the Groups Tab
      await groups.loadGroups(forceRefresh: true);
      // Navigate to the group that was just joined
      Get.back();
      shell.openGroups();
      await groups.ensureGroupLoaded(invitation.groupId, forceRefresh: true);
      // Navigate to group details
      Get.toNamed('/group/${invitation.groupId}');
    }
  }

  Future<void> _decline(GroupInvitation invitation) async {
    final l10n = context.l10n;
    final confirmed = await _confirmDecline(l10n);
    if (!confirmed) return;

    final provider = context.read<InvitationsProvider>();
    final success = await provider.declineInvitation(invitation.invitationId);
    if (success && mounted) {
      provider.onInvitationDeclined(invitation.invitationId);
      AppSnackBar.show(l10n.invitationDeclined(invitation.groupName));
      // Pop back if we're on the invitations screen after declining
      if (provider.items.isEmpty) Get.back();
    }
  }

  Future<bool> _confirmDecline(L10n l10n) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.declineInvitationTitle),
            content: Text(l10n.declineInvitationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.decline),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<InvitationsProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: Responsive.pagePadding(),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: Icon(context.chevronBack, size: 24.w),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.invitations,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontMd,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 40.w),
                ],
              ),
            ),
            Expanded(
              child: _buildBody(l10n, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(L10n l10n, InvitationsProvider provider) {
    if (provider.isInitialLoading || (provider.isLoading && provider.items.isEmpty)) {
      return const _InvitationsSkeleton();
    }

    if (provider.errorMessage != null && provider.items.isEmpty) {
      return _ErrorState(
        message: provider.errorMessage!,
        onRetry: () => provider.loadInvitations(forceRefresh: true),
      );
    }

    if (provider.items.isEmpty) {
      return _EmptyState(l10n: l10n);
    }

    return ListView.separated(
      padding: Responsive.pagePadding().add(EdgeInsets.only(top: 8.h)),
      itemCount: provider.items.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return _InvitationCard(
          invitation: provider.items[index],
          onAccept: provider.isAccepting ? null : () => _accept(provider.items[index]),
          onDecline: provider.isDeclining ? null : () => _decline(provider.items[index]),
          isAccepting: provider.isAccepting,
          isDeclining: provider.isDeclining,
        );
      },
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
    required this.isAccepting,
    required this.isDeclining,
  });

  final GroupInvitation invitation;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isAccepting;
  final bool isDeclining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoading = isAccepting || isDeclining;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: context.palette.border),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: context.palette.brand.withOpacity(0.1),
                backgroundImage: invitation.groupImage.isNotEmpty
                    ? NetworkImage(invitation.groupImage)
                    : null,
                child: invitation.groupImage.isEmpty
                    ? Text(
                        invitation.groupName.isNotEmpty
                            ? invitation.groupName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: context.palette.brand,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.groupName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${l10n.invitedYouToJoin(invitation.inviterName)} · ${invitation.timeAgo}',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: l10n.decline,
                  size: AppButtonSize.small,
                  expand: true,
                  variant: AppButtonVariant.light,
                  isLoading: isDeclining,
                  onPressed: onDecline,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: CustomButton(
                  label: l10n.accept,
                  size: AppButtonSize.small,
                  expand: true,
                  variant: AppButtonVariant.filled,
                  isLoading: isAccepting,
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mail_outline,
            size: 64.w,
            color: context.palette.textMuted,
          ),
          SizedBox(height: 16.h),
          Text(
            l10n.noInvitations,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 15.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48.w, color: AppColors.rose500),
          SizedBox(height: 12.h),
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: 16.h),
          CustomButton(
            label: l10n.retry,
            size: AppButtonSize.small,
            expand: false,
            variant: AppButtonVariant.light,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _InvitationsSkeleton extends StatelessWidget {
  const _InvitationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: Responsive.pagePadding().add(EdgeInsets.only(top: 8.h)),
      itemCount: 3,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (_, __) => Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
    );
  }
}
