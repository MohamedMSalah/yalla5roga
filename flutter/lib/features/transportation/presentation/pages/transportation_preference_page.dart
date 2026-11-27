import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';

import '../providers/transportation_preferences_provider.dart';
import '../widgets/capability_unavailable_message.dart';
import '../widgets/transportation_mode_selector.dart';

class TransportationPreferencePage extends StatefulWidget {
  const TransportationPreferencePage({super.key});

  @override
  State<TransportationPreferencePage> createState() =>
      _TransportationPreferencePageState();
}

class _TransportationPreferencePageState
    extends State<TransportationPreferencePage> {
  late final int _session;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransportationPreferencesProvider>();
    _session = provider.session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && provider.matchesSession(_session)) provider.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<TransportationPreferencesProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transportationTitle)),
      body: SafeArea(
        child: provider.matchesSession(_session)
            ? _body(provider)
            : AppEmptyState(message: l10n.dataLoadFailed),
      ),
    );
  }

  Widget _body(TransportationPreferencesProvider provider) {
    final l10n = context.l10n;
    if (provider.readFailure case final failure?) {
      return AppErrorState(
        message: FailureMessageMapper.localize(failure, l10n),
        onRetry: provider.refresh,
      );
    }
    final preference = provider.preference;
    if (preference == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final capabilities = provider.capabilities;
    final noRoutes =
        capabilities.isNotEmpty &&
        capabilities.every((entry) => !entry.supportsRoutes);
    return ListView(
      padding: Responsive.pagePadding(),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.transportationDefault,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(l10n.transportationDefaultHint),
                const SizedBox(height: 8),
                TransportationModeSelector(
                  value: preference.defaultMode,
                  onChanged: provider.isLoading || provider.isSaving
                      ? null
                      : provider.update,
                ),
                if (provider.isSaving) const LinearProgressIndicator(),
                if (provider.writeFailure case final failure?)
                  Semantics(
                    liveRegion: true,
                    child: Text(FailureMessageMapper.localize(failure, l10n)),
                  ),
                if (noRoutes) ...[
                  const SizedBox(height: 16),
                  CapabilityUnavailableMessage(
                    reasonCode: capabilities.first.unavailabilityReasonCode,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
