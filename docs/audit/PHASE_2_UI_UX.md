# Phase 2 — Dashboard, groups and invitations

Implemented 2026-11-13 on top of the uncommitted Phase 1 foundation. The existing dirty working tree was preserved; this inventory describes Phase 2 additions/edits, not every pre-existing change shown by git status.

## Delivered behavior

| Surface | Implementation |
|---|---|
| Home | Existing time greeting/name/avatar and unread notification bell; shared nearest future outing card with cover/group/schedule/status; shared New Outing/New Group/Special Event actions; real nearby place carousel with See All, location permission/settings guidance and catalog fallback; loading/empty/error/offline states. |
| Groups | Shared header/search/chips; All, Most active and Created by me filters; group bio/member count/outing activity; Create Group. Fixed the previous Most active filter, which excluded every group. Existing Provider/Socket.IO invalidations remain responsible for automatic freshness. |
| Create Group | Focused cover/name/bio and invitee widgets; existing camera/gallery/media pipeline and contacts picker; international/manual phone entry; removable contact chips; typed phone added/validated on submission; locked submission, loading and success feedback; selected invitees survive failed creation. Invitees are never constructed as temporary accepted members. |
| Group Details | Cover/name/bio and role/count header; Create Outing; separate Active Votes and Upcoming sections; Group Info. Uses existing activeVotes/upcoming classification. No tabs or group-level chat. |
| Group Info | Owner-only name sheet, cover editing and bio editing; active-member role/Accepted badges and separate Pending badges; accepted members can invite through the existing endpoint; owner removal/revocation/deletion and confirmed leaving preserved. Links to group-only invitation and completed/cancelled outing history. |
| Invitations | Existing Settings/notification/deep-link entries; shared page bar and bounded body; All/Pending/Accepted/Declined filters; group image/name, inviter and localized invitation date; controls only for pending rows. Decisions retain history. Accept uses a concrete GroupDetailsPage route; decline stays in the history screen. Loading/empty/retry states remain explicit. |

The reported grey screen was not reproduced because app/UI execution was prohibited. The page structure and unsafe named-route navigation were replaced, and static analysis is clean in the affected sources. This is not runtime visual sign-off.

## Architecture and data

Provider/ChangeNotifier, DI, repositories, Dio, account-scoped cache/snapshots, media URL resolution, Firebase authentication and the existing session Socket.IO transport remain in place. No dependencies, mock data, polling, extra refresh mechanism, database migrations or new endpoints were added.

The one additive backend contract change is `invitation_history` on the existing GET `/api/groups/:id/members` response. The existing active-member authorization and repeatable-read roster query protect it. Its rows include persisted status, date, inviter name and invitee name/phone. The pending projection now includes identity-linked pending invitations, which previously disappeared from the roster despite not accepting. Active member count remains separate. The original `data` and `pending_members` fields remain compatible. Older servers decode to empty history; the backend addition must be deployed to populate it.

Invitation accept/decline still uses the same backend operations and verified-phone identity rules. The provider now retains all returned statuses rather than filtering them to pending/removing decided rows. Load generation and account epoch are independent, preventing a realtime load from cancelling a mutation's completion or leaving its spinner stuck. Mutation controls are mutually exclusive and only the affected card shows progress. Existing WhatsApp/outbox code and delivery settings were not changed.

## Reused Phase 1 components

- GroupCard through the feature domain adapter; extended with optional description.
- OutingCard directly on Home and via the existing OutingListTile group adapter; extended with an optional lifecycle badge.
- PlaceCard through DiscoverPlaceCard/FeaturedPlacesList; carousel spacing is directional and height follows the existing large-text card sizing.
- InvitationCard through GroupInvitationCard and group-history rendering; optional status and hidden actions support historical rows.
- UserAvatar, PlanningCover/PlanningCoverPicker, AppHero, NotificationButton, AppPageBar, AppPageHeader, SectionHeader, AppSearchField, FilterChipRow, AppBadge, AppTextField/CustomTextField, PhoneTextField, CustomButton, AppBottomSheet, AppShimmer, AppEmptyState, AppErrorState, AppOfflineIndicator and AppSnackBar.
- Existing AppPalette/AppTheme/Responsive and manual English/Arabic L10n. Badges can wrap long labels; bounded content, directional spacing and keyboard-aware sheets remain in use.

## Changed files (Phase 2 only)

Paths below are repository-relative. Some shared files and adapters were already modified/untracked by Phase 1.

### Flutter core

- `flutter/lib/core/localization/l10n.dart`: English/Arabic filters, invitation states and draft label.
- `flutter/lib/core/widgets/{app_badge,group_card,outing_card,invitation_card}.dart`: wrapping badge labels, descriptions, lifecycle status, historical invitation presentation.

### Home and nearby

- `flutter/lib/features/home/presentation/pages/home_page.dart`
- `flutter/lib/features/home/presentation/widgets/cards/featured_outing_card.dart`
- `flutter/lib/features/home/presentation/widgets/quick_actions.dart`
- `flutter/lib/features/home/presentation/widgets/home_nearby_section.dart` (new)
- `flutter/lib/features/discover/presentation/widgets/lists/featured_places_list.dart`

### Groups

- `flutter/lib/features/groups/data/datasources/groups_remote_datasource.dart`
- `flutter/lib/features/groups/data/repositories/groups_repository_impl.dart`
- `flutter/lib/features/groups/domain/entities/group.dart`
- `flutter/lib/features/groups/domain/entities/group_invitation_record.dart` (new)
- `flutter/lib/features/groups/domain/repositories/groups_repository.dart`
- `flutter/lib/features/groups/presentation/pages/{groups_page,create_group_page,group_details_page,group_info_page}.dart`
- `flutter/lib/features/groups/presentation/pages/group_history_page.dart` (new)
- `flutter/lib/features/groups/presentation/providers/groups_provider.dart`
- `flutter/lib/features/groups/presentation/widgets/cards/{group_card,group_member_card}.dart`
- `flutter/lib/features/groups/presentation/widgets/{group_info_header,group_members_section}.dart`
- `flutter/lib/features/groups/presentation/widgets/lists/{group_outings_list,groups_list}.dart`
- `flutter/lib/features/groups/presentation/widgets/{create_group_fields,group_invitee_picker,group_details_header,group_name_editor,group_history_links,group_invitation_history}.dart` (new)

### Invitations

- `flutter/lib/features/invitations/domain/entities/group_invitation.dart`
- `flutter/lib/features/invitations/domain/repositories/invitations_repository.dart`
- `flutter/lib/features/invitations/presentation/pages/invitations_page.dart`
- `flutter/lib/features/invitations/presentation/providers/invitations_provider.dart`
- `flutter/lib/features/invitations/presentation/widgets/group_invitation_card.dart` (extends Phase 1 adapter)
- `flutter/lib/features/invitations/presentation/widgets/invitations_list.dart` (new)
- `flutter/lib/features/invitations/presentation/invitation_l10n.dart` (new)
- `flutter/lib/features/invitations/data/repositories/invitations_repository_impl.dart` (format only)

### Backend / verification

- `backend/src/types/groups/group.types.ts`
- `backend/src/datasources/groups/group.datasource.ts`
- `backend/src/controllers/groups/group.controller.ts`
- `backend/src/routes/groups/group.members.routes.ts`
- `backend/src/config/swagger.ts`
- `backend/scripts/phase2-openapi-verification.ts` (new; read-only HTTP/schema verification)
- `docs/audit/PHASE_2_OPENAPI_RESULTS.json` (new)

## Verification

| Check | Result |
|---|---|
| Dart format on affected feature directories/core files | PASS, using the installed SDK executable with `--suppress-analytics`; no application launched. |
| Targeted `flutter analyze --no-pub` on Home, Groups, Invitations and modified core/discover sources | PASS: no issues found. |
| Full `flutter analyze --no-pub` | No errors; exit 1 for 21 pre-existing findings outside Phase 2: 5 warnings and 16 informational lints in network, auth, chat, Discover details, invite deep links, FCM and Settings. These were not suppressed or refactored. |
| Dart MCP targeted analyzer | No errors. |
| Backend `pnpm exec tsc --noEmit` | PASS. |
| Swagger/OpenAPI generated history schema and served specification | PASS. |
| OpenAPI-selected HTTP missing/invalid-auth checks: members, inbox, accept, decline | PASS: 8 requests returned the documented 401 and matched error schemas. No fixture or database writes. |
| `git diff --check` | PASS. |
| Flutter/widget/integration/UI/device/emulator tests and app launch/hot reload | NOT RUN, explicitly prohibited. |

See [machine-readable OpenAPI results](PHASE_2_OPENAPI_RESULTS.json). The local listener required normal local-network execution after the sandbox denied loopback access. No production deployment or database change was performed.

## Documentation Updates

- `docs/USER_SCENARIOS.md`: dashboard/group/inbox journeys, automatic updates and history routing; corrected stale Home pull-to-refresh wording and the old all-outings-in-details description.
- `docs/FLUTTER_ARCHITECTURE.md`: focused composition, existing provider/data dependencies, editable group fields, history projection and independent invitation load/account generations.
- `docs/API_CONTRACTS.md`: additive roster history shape, linked pending display, compatibility and deployment requirement.
- `docs/BACKEND_ARCHITECTURE.md`: existing roster chain and repeatable-read projection.
- `docs/AUTHENTICATION_AND_AUTHORIZATION.md`: existing member/owner permissions and pending history boundary.
- `docs/BUSINESS_LOGIC.md`: display consistency for linked pending identities, with acceptance/member counts unchanged.
- `docs/SYSTEM_DESIGN.md`: existing roster/inbox reads and realtime invalidation flow.
- `docs/PROJECT_STRUCTURE.md`: new widgets, entity, history route and verification artifacts.
- This report and the JSON results record validation and limits.

No diagrams changed: component topology, database relationships and product state transitions are unchanged. No remaining task-specific documentation conflict was identified; broader historical docs and unrelated analyzer findings were not audited.

## Remaining issues / unverified behavior

1. Phone/wide/foldable, English/Arabic, light/dark, keyboard/large-text rendering, the grey-screen symptom and interactive Socket.IO/offline recovery remain unexercised under the requested test restrictions.
2. Authenticated roster/history success, accept/decline concurrency, verified-phone matching and physical WhatsApp/FCM delivery were not exercised with task-supplied accounts. The OpenAPI checks prove schemas and authentication rejection, not those authenticated business scenarios.
3. Deploy the additive backend roster projection with this Flutter revision for complete group invitation history. No deployment or migration was requested or performed.
4. Full-project analysis still reports the 21 unrelated warnings/lints listed above. Phase 2 sources pass targeted analysis.
