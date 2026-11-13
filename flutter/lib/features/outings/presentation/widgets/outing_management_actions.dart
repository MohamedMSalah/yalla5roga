import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/edit_outing_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class OutingManagementActions extends StatelessWidget {
  const OutingManagementActions({
    super.key,
    required this.outing,
    required this.userId,
  });
  final Outing outing;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OutingsProvider>();
    final l10n = context.l10n;
    final busy = provider.isManaging(outing.id);
    final owner = userId != null && userId == outing.createdById;
    Future<void> decide(bool accept) async {
      if (!accept &&
          !await AppAlert.confirm(
            title: l10n.declineInvitationTitle,
            message: l10n.declineInvitationMessage,
            confirmText: l10n.decline,
            cancelText: l10n.cancel,
          )) {
        return;
      }
      final ok = await provider.respondToInvitation(outing.id, accept: accept);
      if (!context.mounted) return;
      if (!ok) {
        AppSnackBar.show(provider.errorMessage ?? l10n.tryAgain);
        return;
      }
      if (!accept) Get.back();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.guestsError(outing.id) case final error?) ...[
          Text(error),
          CustomButton(
            label: l10n.retry,
            variant: AppButtonVariant.outlined,
            onPressed: provider.guestsLoading(outing.id)
                ? null
                : () => provider.loadGuests(outing.id),
          ),
        ],
        if (!owner &&
            userId != null &&
            provider.invitationStatus(outing.id, userId!) == 'pending') ...[
          Text(l10n.outingInvitation),
          CustomButton(
            label: l10n.accept,
            isLoading: busy,
            onPressed: busy ? null : () => decide(true),
          ),
          CustomButton(
            label: l10n.decline,
            variant: AppButtonVariant.outlined,
            onPressed: busy ? null : () => decide(false),
          ),
        ],
        if (owner &&
            outing.status != OutingStatus.cancelled &&
            outing.status != OutingStatus.past) ...[
          CustomButton(
            label: l10n.editOuting,
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: busy
                ? null
                : () => Get.to(() => EditOutingPage(outing: outing)),
          ),
          Responsive.spaceSm.gapH,
          CustomButton(
            label: l10n.cancelOuting,
            icon: Icons.cancel_outlined,
            variant: AppButtonVariant.danger,
            isLoading: busy,
            onPressed: busy
                ? null
                : () async {
                    if (!await AppAlert.confirm(
                      title: l10n.cancelOuting,
                      message: l10n.cancelOutingPrompt,
                      confirmText: l10n.cancelOuting,
                      cancelText: l10n.cancel,
                      destructive: true,
                    )) {
                      return;
                    }
                    final ok = await provider.cancel(outing.id);
                    if (context.mounted) {
                      AppSnackBar.show(
                        ok
                            ? l10n.changesSaved
                            : provider.errorMessage ?? l10n.tryAgain,
                      );
                    }
                  },
          ),
        ],
        if (owner && provider.guestsFor(outing.id).isNotEmpty) ...[
          Responsive.spaceMd.gapH,
          Text(
            l10n.manageParticipants,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final guest in provider.guestsFor(outing.id))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(guest.name.isEmpty ? guest.id : guest.name),
              trailing: IconButton(
                tooltip: l10n.removeGuest,
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: busy
                    ? null
                    : () async {
                        if (!await AppAlert.confirm(
                          title: l10n.removeGuest,
                          message: l10n.removeGuestPrompt,
                          confirmText: l10n.removeGuest,
                          cancelText: l10n.cancel,
                          destructive: true,
                        )) {
                          return;
                        }
                        final ok = await provider.removeGuest(
                          outing.id,
                          guest.id,
                        );
                        if (!ok && context.mounted) {
                          AppSnackBar.show(
                            provider.errorMessage ?? l10n.tryAgain,
                          );
                        }
                      },
              ),
            ),
        ],
      ],
    );
  }
}
