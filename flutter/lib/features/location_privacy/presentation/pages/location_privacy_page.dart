import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/pages/my_locations_page.dart';

import '../../domain/entities/location_privacy_settings.dart';
import '../providers/location_privacy_provider.dart';
import '../widgets/location_usage_consent_sheet.dart';
import 'group_exclusions_page.dart';

class LocationPrivacyPage extends StatefulWidget {
  const LocationPrivacyPage({super.key});

  @override
  State<LocationPrivacyPage> createState() => _LocationPrivacyPageState();
}

class _LocationPrivacyPageState extends State<LocationPrivacyPage> {
  late final int _session;

  @override
  void initState() {
    super.initState();
    final provider = context.read<LocationPrivacyProvider>();
    _session = provider.session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && provider.matchesSession(_session)) {
        provider.refreshSettings();
      }
    });
  }

  Future<void> _setAutomaticUsage(
    LocationPrivacyProvider provider,
    LocationPrivacySettings settings,
    bool enabled,
  ) async {
    if (!enabled) {
      await provider.withdrawConsent();
      return;
    }
    final confirmed = await LocationUsageConsentSheet.show(context);
    if (mounted && confirmed == true && provider.matchesSession(_session)) {
      await provider.grantConsent(settings.requiredPolicyVersion);
    }
  }

  Future<void> _openLocations(LocationPrivacyProvider provider) async {
    await Get.to<void>(() => const MyLocationsPage());
    if (mounted && provider.matchesSession(_session)) {
      await provider.refreshSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<LocationPrivacyProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.locationPrivacyTitle)),
      body: SafeArea(
        child: provider.matchesSession(_session)
            ? _body(provider)
            : AppEmptyState(message: l10n.locationSetupUnavailable),
      ),
    );
  }

  Widget _body(LocationPrivacyProvider provider) {
    final l10n = context.l10n;
    final settings = provider.settings;
    if (provider.settingsReadFailure case final failure?) {
      return AppErrorState(
        message:
            '${l10n.locationSetupUnavailable}\n${FailureMessageMapper.localize(failure, l10n)}',
        onRetry: provider.refreshSettings,
      );
    }
    if (settings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final busy = provider.isLoadingSettings || provider.isSavingSettings;
    final canToggle =
        settings.automaticUsageEnabled || settings.canPresentConsent;
    return RefreshIndicator(
      onRefresh: provider.refreshSettings,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.pagePadding(),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.hideMyLocation),
                    subtitle: Text(l10n.locationVisibilityHint),
                    value: settings.visibility == LocationVisibility.hidden,
                    onChanged: busy
                        ? null
                        : (hidden) => provider.updateVisibility(
                            hidden
                                ? LocationVisibility.hidden
                                : LocationVisibility.approximate,
                          ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.allowAutomaticMeetupLocation),
                    subtitle: Text(l10n.automaticMeetupLocationHint),
                    value: settings.automaticUsageEnabled,
                    onChanged: busy || !canToggle
                        ? null
                        : (enabled) =>
                              _setAutomaticUsage(provider, settings, enabled),
                  ),
                  Responsive.spaceSm.gapH,
                  Text(l10n.hiddenLocationConsentHint),
                  if (!canToggle) ...[
                    Responsive.spaceSm.gapH,
                    Text(l10n.locationConsentUpdateRequired),
                  ],
                  if (settings.setupStatus != LocationSetupStatus.ready) ...[
                    Responsive.spaceMd.gapH,
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        settings.setupStatus ==
                                LocationSetupStatus.consentRequired
                            ? l10n.locationSetupConsentRequired
                            : l10n.locationSetupStartingPointRequired,
                      ),
                    ),
                  ],
                  if (settings.setupStatus ==
                      LocationSetupStatus.startingLocationRequired)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: busy ? null : () => _openLocations(provider),
                        child: Text(l10n.myLocations),
                      ),
                    ),
                  if (provider.settingsWriteFailure case final failure?) ...[
                    Responsive.spaceSm.gapH,
                    Semantics(
                      liveRegion: true,
                      child: Text(FailureMessageMapper.localize(failure, l10n)),
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.group_off_outlined),
                    title: Text(l10n.locationExcludedGroups),
                    subtitle: Text(l10n.locationExcludedGroupsHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Get.to<void>(() => const GroupExclusionsPage()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
