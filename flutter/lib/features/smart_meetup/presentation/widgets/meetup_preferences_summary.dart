import 'package:flutter/material.dart';

import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_bottom_sheet.dart';

import '../../domain/entities/meetup_session.dart';
import '../providers/smart_meetup_provider.dart';
import 'applied_preferences_bar.dart';
import 'meetup_preferences_bottom_sheet.dart';

class MeetupPreferencesSummary extends StatelessWidget {
  const MeetupPreferencesSummary({
    super.key,
    required this.session,
    required this.provider,
  });

  final MeetupSession session;
  final SmartMeetupProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preferences = session.preferences;
    final options = provider.preferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune),
          title: Text(l10n.meetupPreferences),
          trailing: session.canManage ? const Icon(Icons.edit_outlined) : null,
          onTap: session.canManage && !provider.loading
              ? () {
                  options.loadCategories();
                  AppBottomSheet.show<void>(
                    context: context,
                    builder: (_) => MeetupPreferencesBottomSheet(
                      initial: preferences,
                      provider: provider,
                      sessionId: session.id,
                    ),
                  );
                }
              : null,
        ),
        ListenableBuilder(
          listenable: options,
          builder: (context, _) => AppliedPreferencesBar(
            preferences: preferences,
            categories: options.categories ?? const [],
          ),
        ),
      ],
    );
  }
}
