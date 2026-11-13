# Phase 1 — Modern Social Flutter foundation

Implemented locally on 2026-11-13. Presentation scope only; no new dependencies.

## Design system

- Violet primary scale (#7C3AED light action, pale violet dark action), readable light/dark semantic surfaces and success/warning/danger/info pairs.
- AppTheme maps tokens to Material 3 buttons, fields, chips, sheets/dialogs, selection, progress and typography. Cairo Arabic and Inter English remain.
- app_tokens.dart centralizes spacing, radii, touch geometry, typography and shadows; Responsive consumes the shared geometry without replacing the established layout system. AppMotion owns durations, curves and shimmer timing.
- New installs default to Arabic RTL; persisted English remains English. Existing manual L10n and number formatters remain. New offline and password-visibility text is localized.

## Component catalog

| Concern | Reusable implementation | Adoption/contract |
|---|---|---|
| Primary/secondary/destructive actions | CustomButton: filled/light/outlined/danger | Same constructor; theme-aware disabled/loading colors, 48dp minimum, growing labels |
| Icon actions | AppIconButton | Same API plus localized tooltip; directional badge, 48dp minimum, restrained motion |
| Form/search | CustomTextField / AppTextField alias; AppSearchField | One field implementation; Groups uses shared search, caller owns controller and query |
| Chips/badges/avatar | FilterChipRow, AppBadge, UserAvatar | Native ChoiceChip focus/selection, semantic warning badge default, existing cached avatar |
| GroupCard | core/widgets/group_card.dart | Feature adapter retains entity/Provider mapping, count localization and Hero cover |
| OutingCard | core/widgets/outing_card.dart | Existing OutingListTile delegates; occasion artwork and Hero tags remain in feature |
| PlaceCard | core/widgets/place_card.dart | Existing DiscoverPlaceCard delegates; feature retains localizations and image/Hero handling |
| InvitationCard | core/widgets/invitation_card.dart | Feature GroupInvitationCard supplies values/actions; buttons lock while either decision is busy; actions stack on narrow/large-text layouts |
| Headers | AppPageHeader; SectionHeader / AppSectionHeader alias; AppPageBar | Groups composes shared header; existing page bar/back contract remains |
| Loading/empty/error | AppShimmer and existing skeletons, AppEmptyState, AppErrorState | Invitation states extracted into feature/widgets and reuse these core components |
| Offline | AppOfflineIndicator | Opt-in local status; no global banner, subscription or sync behavior added |
| Feedback | AppSnackBar, AppAlert | Existing confirmation/success/error APIs retained; shared theme and motion |
| Sheets | AppBottomSheet plus existing specialized sheets | Keyboard-aware, scrollable, safe-area helper; existing sheet APIs retained |
| Images | AppNetworkImage | Existing cached_network_image/media:// account-scoped pipeline retained; theme-aware fallback colors |
| Card input | AppPressable | Existing press animation plus Enter/Space activation and visible keyboard focus |

Shared cards take only presentation values, widgets and callbacks. They do not import feature entities, Providers, APIs or repositories. Existing feature adapters preserve public constructors. Invitation card/states moved out of its page into presentation/widgets; no duplicate card renderer remains there. Legacy pages outside this scope have not been broadly decomposed or restyled.

## Navigation and preserved contracts

The existing MainShell lazy page cache, ShellProvider indexes 0–4, callbacks, route arguments and deep-link handlers remain. Home, Groups, Outings, Discover and Settings retain mounted tab state. The floating bar uses a filled active violet pill, directional indicator positioning, safe-area spacing, a content-width limit and opaque high-contrast handling. Incoming content receives a short directional nudge with reduced-motion support. Hidden tabs cannot accept input, focus, semantics or active tickers. The outgoing-tab animation previously captured completion state outside its animation builder; that calculation now follows animation progress.

No repositories, data sources, API integrations, domain models, business rules, mutation handlers or backend files changed. The invitation decline handler adds a mounted guard before reading context after confirmation; existing decisions and navigation remain. Offline synchronization stays silent globally.

## Verification

- dart format: PASS on all 42 affected Dart files; final run changed 0 files.
- flutter analyze --no-pub (full project): no errors; 21 existing findings outside changed files (5 warnings, 16 infos), so the full command exits 1. They are in network, auth, chat, discover details, invites, notifications and settings. They were left outside this presentation task.
- flutter analyze --no-pub with all 42 affected Dart files: PASS, no issues found (5.6 seconds).
- Source-token contrast calculation: primary/secondary/muted text, hints, brand-on-soft and active chip pairs all exceed 4.5:1 in both themes. Lowest measured ratio: 5.34:1. This is not rendered-image accessibility sign-off.
- git diff --check: PASS.
- No Flutter app launch, hot reload/restart, emulator, device tests, UI automation or runtime/visual inspection. No tests executed; verification is formatting and static analysis as requested.

Phone/wide/foldable, light/dark, Arabic/English, keyboard, long-text and large-text layouts still need runtime visual validation. Foundation components account for these states in code, but that is not proof of rendering. Unrelated legacy feature pages may still contain local styles or large widget trees; this phase deliberately does not redesign them.

## Documentation Updates

DESIGN.md establishes the visual contract and reuse map. FLUTTER_ARCHITECTURE documents tokens, components, adapters, Arabic default and navigation. PROJECT_STRUCTURE maps new files. USER_SCENARIOS and PRODUCT_SCENARIOS record the owner-approved presentation behavior while preserving business rules. ARCHITECTURE_DECISIONS records ADR-020. PROJECT_OVERVIEW corrects the stale four-tab description. No architecture diagram changed because data flow and component/service boundaries are unchanged. Remaining limitations are runtime/visual validation and pre-existing project analyzer findings; no unresolved documentation conflict was found in the touched scope.

## Changed files

- `DESIGN.md`
- `docs/ARCHITECTURE_DECISIONS.md`
- `docs/FLUTTER_ARCHITECTURE.md`
- `docs/PRODUCT_SCENARIOS.md`
- `docs/PROJECT_OVERVIEW.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/USER_SCENARIOS.md`
- `flutter/lib/core/localization/l10n.dart`
- `flutter/lib/core/localization/locale_provider.dart`
- `flutter/lib/core/responsive/responsive.dart`
- `flutter/lib/core/theme/app_colors.dart`
- `flutter/lib/core/theme/app_motion.dart`
- `flutter/lib/core/theme/app_palette.dart`
- `flutter/lib/core/theme/app_theme.dart`
- `flutter/lib/core/theme/app_tokens.dart`
- `flutter/lib/core/widgets/app_badge.dart`
- `flutter/lib/core/widgets/app_bottom_nav.dart`
- `flutter/lib/core/widgets/app_bottom_nav_layout.dart`
- `flutter/lib/core/widgets/app_bottom_sheet.dart`
- `flutter/lib/core/widgets/app_card.dart`
- `flutter/lib/core/widgets/app_empty_state.dart`
- `flutter/lib/core/widgets/app_error_state.dart`
- `flutter/lib/core/widgets/app_icon_button.dart`
- `flutter/lib/core/widgets/app_network_image.dart`
- `flutter/lib/core/widgets/app_offline_indicator.dart`
- `flutter/lib/core/widgets/app_page_bar.dart`
- `flutter/lib/core/widgets/app_page_header.dart`
- `flutter/lib/core/widgets/app_pressable.dart`
- `flutter/lib/core/widgets/app_search_field.dart`
- `flutter/lib/core/widgets/app_section_header.dart`
- `flutter/lib/core/widgets/app_shimmer.dart`
- `flutter/lib/core/widgets/app_snackbar.dart`
- `flutter/lib/core/widgets/app_text_field.dart`
- `flutter/lib/core/widgets/custom_button.dart`
- `flutter/lib/core/widgets/custom_textfield.dart`
- `flutter/lib/core/widgets/filter_chip_row.dart`
- `flutter/lib/core/widgets/group_card.dart`
- `flutter/lib/core/widgets/invitation_card.dart`
- `flutter/lib/core/widgets/notification_button.dart`
- `flutter/lib/core/widgets/outing_card.dart`
- `flutter/lib/core/widgets/place_card.dart`
- `flutter/lib/core/widgets/section_header.dart`
- `flutter/lib/features/discover/presentation/widgets/cards/discover_place_card.dart`
- `flutter/lib/features/groups/presentation/pages/groups_page.dart`
- `flutter/lib/features/groups/presentation/widgets/cards/group_card.dart`
- `flutter/lib/features/invitations/presentation/pages/invitations_page.dart`
- `flutter/lib/features/invitations/presentation/widgets/group_invitation_card.dart`
- `flutter/lib/features/invitations/presentation/widgets/invitations_states.dart`
- `flutter/lib/features/outings/presentation/widgets/cards/outing_list_tile.dart`
- `docs/audit/PHASE_1_FOUNDATION.md`
