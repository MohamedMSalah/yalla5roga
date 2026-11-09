# UI/UX audit and Home redesign

## Scope and method

Source review of Home, shell, outing list/details entry points, quick actions, Groups, Discover, and Notifications, together with the documented journeys and shared controls. This is a heuristic source review, not research with participants or a complete visual audit of every screen. Auth, creation forms, chat, settings, modals, and their edge states still require a screen-by-screen runtime review. Severity estimates describe potential user impact, not measured incidence.

## Findings and priorities

| Priority | Evidence and impact | Recommendation |
| --- | --- | --- |
| P1 | The former Next up carousel iterated over the entire provider list without date/status sorting. Past or cancelled plans could be presented as next, obscuring the relevant plan. | Select the earliest future dated non-terminal outing; keep the complete list accessible. |
| P1 | Initial load failure was displayed as a normal empty featured state, so a connection problem could look like no plans. | Show a recoverable error and retry when no snapshot is available. |
| P2 | Home repeated outings in the carousel and Happening now while two Discover lists preceded them. The label implied live activity without checking dates. | One next plan before actions, one Discover preview, and a link to all outings. |
| P2 | Three small fixed-width quick-action tiles used very small scrolling labels, including a smaller Arabic size; custom gesture targets lacked standard button affordances. | Use a primary creation button and wrapping Material text actions that can grow with text. |
| P2 | Featured text was placed in a fixed-height image overlay with absolute left positioning; long titles and RTL could be difficult. | Use flowing, direction-aware content and a separate thumbnail. |
| P2 | Discover and Outings both show destination previews; the Outings tab places Discover before its filtered outings. | Test navigation with users; consider moving destination browsing to Discover and placing the selected outing list first in a future screen-specific change. |
| P2 | Notification opening marks all read automatically, potentially hiding unread state before individual items are examined. | Validate this behavior with product and users before changing it. |
| P2 | Shared outing tiles use small secondary text and nested shrink-wrapped lists. | Audit readability, text scaling, and scrolling in all consumers before a shared component change. |
| P3 | Header used an emoji as decoration adjacent to a user name. | Keep the compact existing greeting and avatar without decorative glyph. |

## Direction and changes

Home answers “what is my next plan?” first. The compact greeting and notification entry remain, followed by the next dated upcoming outing and an all-outings link. Creating an outing is the primary action; special events and group creation remain available as secondary actions; the Home invite action was removed at the user’s request. A single featured Discover preview retains the existing route to all places. Outing detail navigation and its Hero tag are preserved. No product rules, API contracts, or repository interfaces changed.

`FeaturedOutingCard` now selects the earliest future dated outing excluding past and cancelled statuses. Undated plans remain in the existing outings screen, rather than being presented as the next dated event. Voting is identified as a status only; Home does not assert that a vote or attendance response is required, since the current snapshot may be selectively hydrated. The error state supports retry; pull-to-refresh forces a single outings load. Discover is not refreshed by that gesture. Existing fade and shared Hero behavior supply transitions; the fade respects reduced motion.

## Files and architecture

- `flutter/lib/features/home/presentation/pages/home_page.dart`: hierarchy, provider readiness selection, refresh and loading state.
- `flutter/lib/features/home/presentation/widgets/cards/featured_outing_card.dart`: next-plan selection and flowing card.
- `flutter/lib/features/home/presentation/widgets/quick_actions.dart`: Material primary and wrapping secondary actions; Home invite removed on request.
- `flutter/lib/features/home/presentation/widgets/home_header.dart`: compact greeting cleanup.
- `flutter/lib/core/localization/l10n.dart`: English and Arabic empty/retry copy.
- `flutter/test/home_next_outing_test.dart`: selection regression coverage.

No new state manager or dependency. The shell still owns initial loads; Home uses provider state and makes no requests in build. Selecting only `hasLoaded` at page level avoids rebuilding the whole feed for every provider notification; the featured component observes the snapshot. No claim is made that underlying repository requests were reduced; explicit refresh intentionally forces a load. Existing cache/deduplication remains in place.

## Validation and remaining work

Dart MCP analysis of changed Home files and the new test reported no errors. The earlier full-project analysis reported an undefined `InputFormatters` in the independently modified auth form and unrelated warnings; the missing import was subsequently added to unblock launch. `flutter test --no-pub` passed all 64 tests, including two new next-plan tests and existing request, hydration, localization and motion tests. `flutter analyze --no-pub` reported 21 existing issues, including the auth error above; no changed Home files were listed. No DTD-connected app was found during the earlier run. Windows, Chrome and Edge were detected; a Pixel 6a emulator is installed. On the follow-up, the Pixel 6a emulator was started and an Android debug build attempted; the build did not complete after several minutes and the environment became unresponsive. No current-build screenshot was captured. Device screenshots, before/after comparison, visual scrolling and interaction checks, TalkBack, contrast measurement, light/dark, English/Arabic, large text, small/wide/foldable layouts, and runtime performance remain unverified. No user research was performed. The initial scope of a complete application-wide screen audit remains incomplete; screen-specific findings above are a starting point, not a certification.

Prioritize a runtime audit of onboarding/auth and invite acceptance, outing creation/voting/attendance, chat and keyboard behavior, then settings and saved content. Validate a trustworthy action-required signal and invitation acceptance journey before adding a Home attention module. Measure network requests and screen-reader traversal on a real session.


## Follow-up source audit, 2026-11-09

This pass surveyed the registered page inventory and traced representative screens and shared controls across authentication, Home/shell, groups and contacts, outing creation/details/location/invites/saved, Discover, notifications, chat, and settings. Findings below are source-based; they are not evidence that all routes or state combinations were exercised at runtime. Severity describes likely impact and should be validated with users.

| Priority | Surface and evidence | Impact and recommendation |
| --- | --- | --- |
| P1 | `app.dart` clamps the system text scale to 0.9–1.15 globally. | Users who request larger text cannot receive their selected size. Remove the cap after making layouts resilient, then test 1.3–2.0 scaling throughout the app. |
| P1 | `event_page.dart` maps every status except voting and past to the confirmed label. | Draft and cancelled outings can be presented as confirmed. Use an exhaustive status-to-label mapping and test each state. |
| P1 | `event_page.dart` uses `stillNotVoted` for unset attendance. | This describes a place vote rather than attendance, contrary to the documented distinction. Use attendance-specific wording and test the two independent states. |
| P1 | `saved_outings_provider.dart` discards remove failures; `saved_outings_page.dart` always announces removal. | A user may be told a saved item or draft was removed when it was not. Return a success/failure result, display an actionable error and preserve the item. |
| P2 | `SavedOutingsProvider.load` ignores both errors and the page renders empty items without a loading/error branch. | A failed or unfinished load can look like an empty saved list. Add distinct loading, error/retry and empty states. |
| P2 | `AppIconButton` defaults to a 40 logical-pixel visual and hit area and has no semantic-label parameter; saved-item deletion explicitly requests 32. It is used for notification, back, map, and save controls. | Screen-reader users may hear an unlabeled button, and touch targets can be below 48dp. Add localized semantics and a minimum effective target while retaining visual size, then verify all callers. |
| P2 | The auth page switches modes through a text-only `GestureDetector`, and provides separate tabs for the same choice. | The text target is small and its semantics are not explicit. Consolidate or use a labeled Material button with a sufficient target. |
| P2 | Opening group details prompts for contacts in `initState`, before the user chooses a contact-related action. | An unexpected permission request can interrupt browsing. Request it in context when selecting contacts, subject to product review. |
| P2 | `AppPageBar` fixes its preferred height and truncates title/subtitle to one line; the bottom navigation has a fixed height and caption-sized labels. | Large text or long translations may clip or lose context. Exercise text scaling and RTL and adapt height/labels where necessary. |
| P2 | Location picker positions map actions using physical `right`, while the page bar and several icon controls do not supply labels. | RTL placement and screen-reader discoverability need validation. Prefer logical positioning when meaningful and add localized labels. |
| P2 | Chat reports failures via shared feedback but the empty message branch does not distinguish a failed initial load from no messages. | An error can be followed by a misleading empty state. Add a persistent retry state and test offline/reconnect behavior. |
| P2 | Settings uses several fixed light accent fills and the Outings page places Discover ahead of the selected outings. | Validate dark-theme contrast and task priority in a dedicated review before changing shared styling or navigation. |
| P3 | Group and outing details have prominent fixed-height image covers and multiple sections; long content is scrollable. | Check crop, hierarchy, scaling, and density with populated real accounts; retain existing identity. |

**Coverage notes:** Splash/auth and signup; group list/details/info/create/contact picker; outings list/create/details/attendance/voting/saved/drafts/guest picker/location picker; Discover list/details; chat; notifications; settings/profile/edit/help/about; shell and Home were included in the source inventory. Invite acceptance/deep links and transient sheets require end-to-end fixtures and explicit journey checks. Source inspection cannot validate network failures, accessibility announcements, keyboard behavior, permissions, image crop, actual contrast, or animation performance.

The follow-up removed the Home invite button as requested and added the missing auth formatter import; group and outing invitation flows were not changed. The emulator attempt did not reach a running app. A second debug APK build with the emulator stopped also remained in Gradle without completing and was stopped. Visual validation remains incomplete. No before screenshot exists for this iteration.

Follow-up checks: the Home quick-actions widget tests passed in English and Arabic at 320 logical pixels and 1.5× text scale. This tests the isolated component with the requested scale; the production app currently clamps system scaling. Targeted Dart analysis of the Home action, auth import, and widget test reported no errors. Full `flutter analyze --no-pub` reported no errors but exited nonzero for 20 existing warnings/informational issues. The earlier complete regression run passed 64 tests before this follow-up.
