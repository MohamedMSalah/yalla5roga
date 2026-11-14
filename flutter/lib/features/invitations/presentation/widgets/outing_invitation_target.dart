import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/notification_card.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';

/// The outing is refreshed and authorized by notification navigation before entry.
class OutingInvitationTarget extends StatelessWidget {
  const OutingInvitationTarget({super.key, required this.outing});
  final Outing outing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: Responsive.pagePadding(),
    child: NotificationCard(
      title: context.l10n.outingInvitation,
      body: outing.title,
      time: outing.dateTimeLine(context.l10n.digits),
      unread: false,
      icon: Icons.mail_outline_rounded,
      actionLabel: context.l10n.viewOuting,
      onTap: () => Get.to(() => EventPage(event: outing)),
      onAction: () => Get.to(() => EventPage(event: outing)),
    ),
  );
}
