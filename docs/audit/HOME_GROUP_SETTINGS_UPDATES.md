# Home, group leave and Settings updates — 2026-11-14

## Implemented

- HomeNearbySection removes Find places near me, location hints and permission buttons. It uses up to six randomly ordered active database records from the existing nearby API when a passive location lookup succeeds. Sample identities remain stable during ordinary rebuilds. Without nearby data, existing real catalog records show under Places to explore, without pretending distance is known. Existing shared cards, details/creation routes, loading/empty/errors and See All remain. Retry reloads nearby and catalog requests. Concurrent nearby loads share one request.
- MainShell starts its permission sequence on the first authenticated frame, independently of data hydration. Notification permission finishes first; FCM follow-up runs only if permission is granted. Location explanation/system permission follows. Launch prompts are once per process session; denial preserves browsing and location denial does not automatically open Settings. A successful location grant signals mounted Home to reload. Permission listener disposal and platform-error guards are present.
- Group Info removes the separate Delete Group action. Confirmed Leave refreshes the roster without stale fallback. A sole active owner calls the existing delete API; ordinary members use the existing self-member leave API. Account epochs reject account-stale completions while ordinary background refreshes no longer invalidate the leave action. The sole-owner confirmation explains deletion and the existing outing-history restriction.
- Backend DeleteGroupUseCase threads caller UID through the existing repository/interface into GroupDatasource. The existing transaction/group row lock rechecks ownership and exactly one active member before applying the existing no-outings guard. Other members or any outing cause 409 without removing the group. The existing last-owner self-removal prohibition remains. Pending invitations are not active members. No new endpoint or migration.
- SettingsAccountSection removes Change Photo and Account Information shortcuts; Edit Profile/avatar photo editing remains. The theme tile shows moon in dark mode and sun in light mode.
- NotificationsProvider persists both pushEnabled values through the existing repository/API with immediate pending state, busy protection, rollback and preference revisions protecting against stale feed results. Settings holds its busy flag through OS permission, FCM registration and save; explicit notification permission requests are deduplicated and can retry a startup skip. Failed permission access leaves the setting unchanged.
- Existing LocalNotificationsService reconciliation stores per-account push policy through SharedPreferencesAsync, cancels disabled alerts and suppresses incoming/native/offline fallback display while disabled. Native rendering rechecks after display to cancel an in-flight alert if push was disabled. Silent dismissal controls remain processable. Account cleanup removes the flag. Backend delivery continues to use canonical Neon preferences. Notification history and inbox synchronization remain enabled.
- Existing AppSwitch track design remains, with nullable disabled callbacks, toggled semantics, logical RTL alignment, reduced-motion support and a real 48dp hit area.

## Changed implementation files

Flutter:
- `lib/features/home/presentation/widgets/home_nearby_section.dart`
- `lib/features/shell/presentation/pages/main_shell.dart`
- `lib/core/utils/app_permissions.dart`
- `lib/core/widgets/app_switch.dart`
- `lib/core/localization/l10n.dart`
- `lib/features/groups/presentation/pages/group_info_page.dart`
- `lib/features/groups/presentation/widgets/group_info_actions_section.dart`
- `lib/features/groups/presentation/providers/groups_provider.dart`
- `lib/features/setting/presentation/widgets/settings_account_section.dart`
- `lib/features/setting/presentation/widgets/settings_preferences_section.dart`
- `lib/features/notifications/presentation/providers/notifications_provider.dart`
- `lib/features/notifications/data/services/local_notifications_service.dart`

Backend:
- `src/usecases/groups/delete-group.usecase.ts`
- `src/repositories/groups/{group.repository,i-group.repository}.ts`
- `src/datasources/groups/group.datasource.ts`
- `src/routes/groups/group.crud.routes.ts`
- `scripts/home-group-settings-openapi-verification.ts`

## Validation

- Backend TypeScript `tsc --noEmit`: passed.
- Dart MCP targeted analysis: No errors.
- Scoped Dart SDK formatting using --suppress-analytics and git diff --check: passed.
- [Swagger/OpenAPI HTTP results](HOME_GROUP_SETTINGS_OPENAPI_RESULTS.json): **32/32 passed** using real application routes/use cases/PostgreSQL in an isolated disposable schema and controlled Firebase identity boundary. The schema was removed; no application-schema data, migrations or delivery workers were changed/run.
- Covered: served contract equality/authentication, preference off/on persistence and feed round-trip, unchanged category preference, user isolation, invalid preference rejection, sole-owner delete success, outsider rejection, populated-group delete conflict, last-owner leave rejection, normal member leave, deletion after that leave, and preservation of a sole-owner group with an outing.
- The first fixture used one initial vote option, which the existing create API correctly rejected. It was corrected to the documented two-option minimum; the complete rerun passed.
- Independent source review found and then confirmed fixes for misleading fallback labels, incomplete nearby retry, misplaced PATCH documentation and duplicate permission dialogs. Follow-up verdict applies only to those source fixes.
- No Flutter run/build/test, emulator, device, visual verification or hot reload was performed. The previous automatic rejection of runtime validation was respected without retry. Phone/wide/foldable, Arabic/English, light/dark, keyboard/focus, native prompts, physical GPS and background/terminated OS delivery remain unverified. HTTP checks do not prove native delivery or switch rendering.

## Documentation Updates

Updated canonical `PRODUCT_SCENARIOS.md`, `USER_SCENARIOS.md`, `FLUTTER_ARCHITECTURE.md`, `BACKEND_ARCHITECTURE.md`, `API_CONTRACTS.md`, `BUSINESS_LOGIC.md`, `SYSTEM_DESIGN.md`, `AUTHENTICATION_AND_AUTHORIZATION.md`, `NOTIFICATIONS.md` and `PROJECT_STRUCTURE.md` for the approved interaction, startup ordering, transactional deletion rule, preference/UI state and verifier files. This report and its JSON record results. Architecture diagrams remain valid and unchanged; no new pattern or schema was introduced. No unresolved inconsistency was identified in the updated sections. Historical reports remain snapshots. Groups with outings intentionally still cannot be deleted by leaving.

The checkout contained extensive prior uncommitted work. This task preserves that work and adds only the scoped changes above; no commit, push, app build or deployment was requested/performed.
