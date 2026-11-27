import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/failure_message_mapper.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';

import '../providers/location_privacy_provider.dart';

class GroupExclusionsPage extends StatefulWidget {
  const GroupExclusionsPage({super.key});

  @override
  State<GroupExclusionsPage> createState() => _GroupExclusionsPageState();
}

class _GroupExclusionsPageState extends State<GroupExclusionsPage> {
  late final int _session;

  @override
  void initState() {
    super.initState();
    final provider = context.read<LocationPrivacyProvider>();
    _session = provider.session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && provider.matchesSession(_session)) {
        provider.refreshGroups();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<LocationPrivacyProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.locationExcludedGroups)),
      body: SafeArea(
        child: provider.matchesSession(_session)
            ? _body(provider)
            : AppEmptyState(message: l10n.dataLoadFailed),
      ),
    );
  }

  Widget _body(LocationPrivacyProvider provider) {
    final l10n = context.l10n;
    if (provider.groupsReadFailure case final failure?) {
      return AppErrorState(
        message: FailureMessageMapper.localize(failure, l10n),
        onRetry: provider.refreshGroups,
      );
    }
    final groups = provider.groups;
    if (groups == null) return const Center(child: CircularProgressIndicator());
    if (groups.isEmpty) {
      return AppEmptyState(message: l10n.locationExcludedGroupsEmpty);
    }
    final busy = provider.isLoadingGroups || provider.savingGroupId != null;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
        child: RefreshIndicator(
          onRefresh: provider.refreshGroups,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: Responsive.pagePadding(),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.locationExcludedGroupsHint),
                    if (provider.groupsWriteFailure case final failure?)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          FailureMessageMapper.localize(failure, l10n),
                        ),
                      ),
                  ],
                );
              }
              final group = groups[index - 1];
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(group.name),
                value: provider.isGroupExcluded(group.id),
                onChanged: busy
                    ? null
                    : (excluded) =>
                          provider.setGroupExcluded(group.id, excluded),
              );
            },
          ),
        ),
      ),
    );
  }
}
