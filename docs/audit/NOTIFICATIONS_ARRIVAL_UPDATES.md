# Notifications app-bar action, loading bars and scheduled arrivals — 2026-11-15

The requested implementation was already present in the working tree when this verification pass began. It was checked against the current source without overwriting concurrent places-ingestion work.

## Current behavior

- Notifications uses the existing AppPageBar trailing slot with trailingOnRight=true, keeping the localized text action on the physical right in both locales. English text is exactly `mark all as read`; Arabic is localized. It calls NotificationsProvider.markAllRead and is disabled with no unread items or while a read mutation is pending. The former body action is removed; All/Unread filters and navigation remain.
- All indeterminate LinearProgressIndicator loading bars are removed from Discover, place details, map picking, catalog controls, group history/bio, event details, RSVP/attendance and arrival presentation. A source search finds only two LinearProgressIndicator instances: both have explicit data values for ballot/result proportions. Skeletons, button busy states, offline/error/retry and other meaningful feedback remain.
- OutingArrivalsSection gates roster fetching, arrival-driven connect, refresh scheduling and GPS verification behind an explicit non-null scheduledAt that has arrived. A visible foreground route schedules a one-shot start timer and starts automatically when due; route/background changes cancel timers and resume/schedule changes re-evaluate time. Undated outings do not begin tracking. A localized waiting message replaces early searching.
- OutingArrivalService rechecks the authoritative roster opening/closing timestamps and route activity before permission/GPS work and before recording. Existing backend venue/confirmation/membership/accuracy/radius/window policy remains authoritative. RSVP and voting remain independent.

## Scoped implementation

`flutter/lib/features/notifications/presentation/pages/notifications_page.dart`, `core/widgets/app_page_bar.dart`, manual L10n, existing loading-bar sites, `features/outings/presentation/widgets/outing_arrivals_section.dart` and `providers/outing_arrival_service.dart`. No new backend endpoint, migration, dependency or navigation route is required for these interactions.

## Verification

- Current source inspected for the notification action, right-side placement, arrival route/lifecycle/start guards and service-level window checks.
- Current source search confirms zero indeterminate LinearProgressIndicator widgets; both remaining occurrences supply vote/result values.
- Targeted Dart MCP analysis of 13 affected source files: **No errors**. Scoped formatter verification: four key notification/arrival files required no formatting changes. Scoped git diff --check passed. No app launch, Flutter/emulator/device tests or hot reload was performed under the existing execution restriction.
- Existing task-specific [OpenAPI result artifact](NOTIFICATIONS_ARRIVAL_OPENAPI_RESULTS.json) contains **27 PASS** checks with its original UTC timestamp: served Swagger/OpenAPI, authenticated mark-all read, before/during/after arrival-window handling, persisted arrivals and participant isolation. Its disposable schema was removed. These backend checks were not rerun during this source-verification pass; no backend arrival/notification contract changed here.
- Whole-tree whitespace verification also encountered a pre-existing trailing blank line in concurrent `backend/src/services/places/taxonomy.ts`; that unrelated file was not edited. Scoped whitespace checks cover only this task.
- Native timing, prompt behavior, physical GPS, text scaling, RTL/light/dark layout and frame/gesture behavior require runtime verification; no visual or device sign-off is claimed.

## Documentation Updates

The current canonical PRODUCT_SCENARIOS, USER_SCENARIOS, BUSINESS_LOGIC, SYSTEM_DESIGN, FLUTTER_ARCHITECTURE and NOTIFICATIONS sections already describe these approved behaviors. PROJECT_STRUCTURE links this verification report. Diagrams remain unchanged because no component/data architecture or schema changed. No inconsistency was found in the reviewed task sections; unrelated ingestion changes remain outside scope.
