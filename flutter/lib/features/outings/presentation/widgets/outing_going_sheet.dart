import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/member_display_name.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/core/widgets/app_network_image.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';
import 'package:yalla_5roga/features/outings/presentation/widgets/outing_attendance_widget.dart';

class OutingGoingSheet {
  const OutingGoingSheet._();

  static Future<void> show(Outing event) {
    final context = Get.context;
    final outings = context == null
        ? null
        : Provider.of<OutingsProvider>(context, listen: false);
    return Get.bottomSheet(
      SafeArea(
        child: outings == null
            ? _OutingGoingSheetBody(eventId: event.id)
            : ChangeNotifierProvider<OutingsProvider>.value(
                value: outings,
                child: _OutingGoingSheetBody(eventId: event.id),
              ),
      ),
      isScrollControlled: true,
    );
  }
}

class _OutingGoingSheetBody extends StatelessWidget {
  const _OutingGoingSheetBody({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final outings = context.watch<OutingsProvider>();
    final event = outings.findById(eventId);
    if (event == null) {
      return const SizedBox.shrink();
    }
    final members = outings.membersForOuting(event);
    final going = outings.goingCountFor(event.id);

    return Container(
      height: Responsive.height * 0.55,
      padding: Responsive.padding(all: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.whoIsGoing,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: Responsive.fontMd,
            ),
          ),
          Text(
            l10n.goingCount(going),
            style: TextStyle(
              color: palette.textMuted,
              fontSize: Responsive.fontSm,
            ),
          ),
          Responsive.spaceMd.gapH,
          Expanded(
            child: members.isEmpty
                ? AppEmptyState(
                    icon: Icons.people_outline,
                    message: l10n.noGoingYet,
                    subtitle: l10n.noGoingYetHint,
                    compact: true,
                  )
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final status = outings.attendanceFor(event.id, member.id);
                      final name = l10n.digits(
                        MemberDisplayName.resolve(member),
                      );
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == members.length - 1 ? 0 : 8.h,
                        ),
                        child: Row(
                          children: [
                            AppNetworkImage.avatar(
                              url: member.avatar,
                              width: 44.w,
                              height: 44.w,
                              radius: 12.r,
                            ),
                            12.gapW,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    AttendanceDisplay.label(status, l10n),
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              AttendanceDisplay.icon(status),
                              color: AttendanceDisplay.color(
                                status,
                                palette.textMuted,
                              ),
                              size: 18.w,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
