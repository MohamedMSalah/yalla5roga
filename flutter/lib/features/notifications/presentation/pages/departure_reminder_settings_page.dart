import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/saved_locations/presentation/providers/saved_locations_provider.dart';

import '../../domain/repositories/location_travel_notification_repository.dart';
import '../providers/departure_reminder_preferences_provider.dart';
import '../widgets/preparation_time_selector.dart';

class DepartureReminderSettingsPage extends StatelessWidget {
  const DepartureReminderSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final saved = context.read<SavedLocationsProvider>();
    final generation = context.select((SavedLocationsProvider p) => p.session);
    final account = auth.isAuthenticated ? auth.user?.id : null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.departureReminders)),
      body: account == null
          ? Center(child: Text(context.l10n.errorSessionExpired))
          : ChangeNotifierProvider(
              key: ValueKey((account, generation)),
              create: (context) => DepartureReminderPreferencesProvider(
                context.read<LocationTravelNotificationRepository>(),
                account,
                () =>
                    auth.isAuthenticated &&
                    auth.user?.id == account &&
                    saved.matchesSession(generation),
              )..load(),
              child: const _DepartureReminderSettings(),
            ),
    );
  }
}

class _DepartureReminderSettings extends StatelessWidget {
  const _DepartureReminderSettings();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DepartureReminderPreferencesProvider>();
    final l10n = context.l10n;
    final value = provider.value;
    final failure = provider.failure;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
        child: ListView(
          padding: Responsive.pagePadding(),
          children: [
            if (provider.busy) const LinearProgressIndicator(),
            if (value != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.departureReminders),
                subtitle: Text(l10n.departurePreferenceHint),
                value: value.enabled,
                onChanged: provider.busy
                    ? null
                    : (enabled) => provider.update(enabled: enabled),
              ),
              if (value.enabled)
                PreparationTimeSelector(
                  minutes: value.bufferMinutes,
                  onChanged: provider.busy
                      ? null
                      : (minutes) => provider.update(bufferMinutes: minutes),
                ),
            ],
            if (failure != null) ...[
              Text(FailureMessageMapper.localize(failure, l10n)),
              TextButton(onPressed: provider.load, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}
