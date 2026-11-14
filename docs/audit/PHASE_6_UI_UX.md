# Phase 6 — Settings, saved/history and authentication

Implemented 2026-11-14 using the established design system. Firebase verification, backend session/user synchronization, Provider architecture, imperative GetX routing and API contracts are preserved. No backend application source, database schema or dependency changes were needed.

## Delivered

- Focused Account, Preferences, Support and About sections compose existing SettingsTile/SettingsSection, ProfileHeader and shared StatCard. Profile editing/photo selection, verification/member date, account information, confirmations, saved/history/invitations/theme/notifications/language/support/policy/developer actions remain available.
- Statistics show real loaded groups, outings and server-completed (`past`) outings. Completed is not RSVP or verified physical attendance; unknown counts show an em dash before loading.
- Saved cards reuse OutingListTile → OutingCard. Bookmarks refresh authorized details and open EventPage; drafts still resume CreateOutingPage. Loading, empty, partial-failure and retry states use existing feedback components. History preserves established started/past/cancelled classification and completed read-only chat routing.
- Branded three-step onboarding describes groups, plans/voting and nearby discovery, with Next/Skip/Get Started and localized progress. The existing preferences instance stores completion. Restored authenticated users go directly to MainShell/Home; completed signed-out starts go to Login. No previous onboarding preference was present in inspected source.
- AuthScaffold and SignupPhotoPicker focus presentation. Login retains validation/loading/network/timeout/error handling and navigation. Signup adds password confirmation and an optional profile image using the existing camera/gallery and media upload service after verified registration. Photo failure does not repeat account creation. Recovery adds shared progress to its unchanged phone/isolated Firebase OTP/new-password flow.
- Delete Account now calls the existing self-profile DELETE instead of merely signing out. Only successful deletion invokes existing logout and account-scoped provider/cache cleanup. The endpoint can reject referenced profiles with 409; it deletes the Neon profile and does not delete/revoke Firebase identity. This existing server limitation is retained and documented.

## Verification

- `dart format` completed successfully for the scoped Dart files.
- `flutter analyze --no-pub` completed: **zero errors, 4 existing warnings and 12 existing info findings**, exit 1 because of those findings. No new Phase 6 diagnostics remain. Existing findings concern unused auth repository helpers, unawaited futures in existing auth methods, braces, initializing formals and an unrelated unused import.
- Dart MCP analysis of the targeted paths returned `No errors`.
- `git diff --check` passed.
- `node --import tsx scripts/phase6-openapi-verification.ts`: **16 checks passed**. Verified served Swagger spec, existing login/signup/recovery request/success contracts, and missing/invalid token rejection for profile get/delete, saved list, current-user outings and details. Evidence: PHASE_6_OPENAPI_RESULTS.json.
- No real accounts/data were mutated. Authenticated successful deletion, Firebase SMS, signup/recovery success were not executed. The script has no fixtures, workers or writes.
- No Flutter/device/emulator/UI tests, app launch or hot reload were run, as requested. Phone/wide/foldable, light/dark, Arabic/English, keyboard, large-text, camera permissions and OTP delivery have no visual/runtime sign-off.
- Independent static finish review and extraction verdict pass found no confirmed introduced blocker; neither is a visual verdict.

## Documentation Updates

FLUTTER_ARCHITECTURE documents component/state ownership; USER_SCENARIOS documents entry/account/saved journeys; AUTHENTICATION_AND_AUTHORIZATION documents unchanged proof contracts and real deletion semantics; SYSTEM_DESIGN documents the entry decision; PROJECT_STRUCTURE maps new files. No architecture/API/schema/notification contract changed. No diagrams were changed. DESIGN.md remains the existing authority and was not changed by this task. Remaining known limits are the existing deletion endpoint semantics, existing analyzer findings and unexecuted visual/authenticated checks listed above; no new documentation inconsistency was identified in this scope.

## Changed files

Task-scoped inventory (other modifications already present in the working tree are excluded):

- `flutter/lib/app.dart`
- `flutter/lib/core/localization/l10n.dart`
- `flutter/lib/core/widgets/stat_card.dart`
- `flutter/lib/features/auth/data/datasources/auth_remote_datasource.dart`
- `flutter/lib/features/auth/data/repositories/auth_repository_impl.dart`
- `flutter/lib/features/auth/domain/repositories/auth_repository.dart`
- `flutter/lib/features/auth/presentation/pages/auth_page.dart`
- `flutter/lib/features/auth/presentation/pages/password_recovery_page.dart`
- `flutter/lib/features/auth/presentation/providers/auth_provider.dart`
- `flutter/lib/features/auth/presentation/widgets/auth_form.dart`
- `flutter/lib/features/auth/presentation/widgets/auth_header.dart`
- `flutter/lib/features/auth/presentation/widgets/auth_tabs.dart`
- `flutter/lib/features/auth/presentation/widgets/auth_scaffold.dart`
- `flutter/lib/features/auth/presentation/widgets/signup_photo_picker.dart`
- `flutter/lib/features/outings/presentation/pages/saved_outings_page.dart`
- `flutter/lib/features/outings/presentation/pages/outing_history_page.dart`
- `flutter/lib/features/outings/presentation/providers/saved_outings_provider.dart`
- `flutter/lib/features/setting/presentation/pages/settings_page.dart`
- `flutter/lib/features/setting/presentation/pages/edit_profile_page.dart`
- `flutter/lib/features/setting/presentation/widgets/lists/settings_list.dart`
- `flutter/lib/features/setting/presentation/widgets/settings_section.dart`
- `flutter/lib/features/setting/presentation/widgets/settings_tile.dart`
- `flutter/lib/features/setting/presentation/widgets/profile_stats.dart`
- `flutter/lib/features/setting/presentation/widgets/delete_account_action.dart`
- `flutter/lib/features/setting/presentation/widgets/settings_account_section.dart`
- `flutter/lib/features/setting/presentation/widgets/settings_preferences_section.dart`
- `flutter/lib/features/setting/presentation/widgets/settings_support_section.dart`
- `flutter/lib/features/setting/presentation/widgets/settings_about_section.dart`
- `flutter/lib/features/splash/presentation/pages/splash_page.dart`
- `flutter/lib/features/splash/presentation/providers/onboarding_provider.dart`
- `flutter/lib/features/splash/presentation/widgets/onboarding_content.dart`
- `backend/scripts/phase6-openapi-verification.ts`
- `docs/audit/PHASE_6_OPENAPI_RESULTS.json`
- `docs/FLUTTER_ARCHITECTURE.md`
- `docs/USER_SCENARIOS.md`
- `docs/AUTHENTICATION_AND_AUTHORIZATION.md`
- `docs/SYSTEM_DESIGN.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/audit/PHASE_6_UI_UX.md`
