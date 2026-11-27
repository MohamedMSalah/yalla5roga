import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';

import '../../domain/entities/meetup_results.dart';

class MeetupReadinessSummary extends StatelessWidget {
  const MeetupReadinessSummary({super.key, required this.result});
  final MeetupResults result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = result.includedParticipantCount;
    final total = result.intendedParticipantCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          l10n.meetupParticipantsReady(ready, total),
          style: context.texts.titleLarge,
        ),
        if (total > 0)
          LinearProgressIndicator(
            value: ready / total,
            semanticsLabel: l10n.meetupParticipantsReady(ready, total),
          ),
      ],
    );
  }
}

class StaleResultsBanner extends StatelessWidget {
  const StaleResultsBanner({super.key});

  @override
  Widget build(BuildContext context) => MeetupResultNotice(
    icon: Icons.update_outlined,
    message: context.l10n.meetupStaleResults,
  );
}

class PartialResultsBanner extends StatelessWidget {
  const PartialResultsBanner({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => MeetupResultNotice(
    icon: Icons.group_outlined,
    message: context.l10n.meetupPartialResults(count),
  );
}

class MeetupResultNotice extends StatelessWidget {
  const MeetupResultNotice({
    super.key,
    required this.icon,
    required this.message,
  });
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(leading: Icon(icon), title: Text(message)),
  );
}
