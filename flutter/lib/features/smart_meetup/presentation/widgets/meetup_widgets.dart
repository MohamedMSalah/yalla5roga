import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_shimmer.dart';

import '../../domain/entities/meetup_session.dart';

class SmartMeetupButton extends StatelessWidget {
  const SmartMeetupButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    icon: const Icon(Icons.route_outlined),
    label: Text(context.l10n.smartMeetup),
  );
}

class MeetupReadinessHeader extends StatelessWidget {
  const MeetupReadinessHeader({super.key, required this.summary});
  final MeetupReadinessSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.meetupReadyCount(summary.usable, summary.intended),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: summary.intended == 0 ? 0 : summary.usable / summary.intended,
          semanticsLabel: l10n.meetupReadyCount(
            summary.usable,
            summary.intended,
          ),
        ),
      ],
    );
  }
}

class MemberReadinessTile extends StatelessWidget {
  const MemberReadinessTile({
    super.key,
    required this.member,
    this.requestAction,
  });
  final MeetupParticipantReadiness member;
  final Widget? requestAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final readiness = member.ready ? l10n.meetupReady : l10n.meetupNeedsSetup;
    return ListTile(
      leading: Icon(
        member.ready ? Icons.check_circle_outline : Icons.location_off_outlined,
      ),
      title: Text(
        member.isSelf ? l10n.meetupYourName(member.name) : member.name,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [readiness, member.district ?? l10n.meetupAreaHidden].join(' · '),
          ),
          ?requestAction,
        ],
      ),
    );
  }
}

class MissingLocationsBanner extends StatelessWidget {
  const MissingLocationsBanner({
    super.key,
    required this.count,
    required this.onRequestSetup,
  });
  final int count;
  final VoidCallback onRequestSetup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.meetupMissingCount(count)),
            TextButton.icon(
              onPressed: onRequestSetup,
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.meetupCopyRequest),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutingUnavailableWidget extends StatelessWidget {
  const RoutingUnavailableWidget({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.route_outlined),
      title: Text(context.l10n.meetupRoutingUnavailable),
      subtitle: Text(context.l10n.meetupRoutingHint),
    ),
  );
}

class MeetupSkeleton extends StatelessWidget {
  const MeetupSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const AppShimmer(
    child: Column(
      children: [
        ShimmerBone(width: double.infinity, height: 48, radius: 12),
        SizedBox(height: 12),
        ShimmerBone(width: double.infinity, height: 84, radius: 12),
        SizedBox(height: 12),
        ShimmerBone(width: double.infinity, height: 168, radius: 12),
      ],
    ),
  );
}
