# Yalla 5roga — Modern Social foundation

Phase 1, 2026-11-13. Scope: the Flutter design system, reusable controls and existing five-tab shell. Mode: Operate. Product behavior remains governed by docs/PRODUCT_SCENARIOS.md.

Use violet as the action and selection accent, quiet light surfaces and deep low-glare dark surfaces. Keep secondary text readable rather than faint. Use semantic palette roles rather than raw colors in new shared UI. Cairo serves Arabic; Inter serves English. Arabic RTL is the first-install default and English LTR is supported. Keep localizations and existing number formatters in the feature adapter.

Tokens belong in flutter/lib/core/theme/: AppColors primitives, AppPalette semantic roles, AppTheme Material 3 mapping, AppMotion durations/curves/reduced-motion helpers, and app_tokens.dart spacing/radii/sizes/type/shadows. Responsive continues to own scaling and wide/foldable content limits. Cards use 16dp corners and one soft offset shadow; controls use 14dp corners. Sheets/dialogs use 24dp corners. Navigation is the floating pill exception. Interactive targets never shrink below 48dp. Text can wrap; controls must grow with text. Use established Material rounded/outlined icons without adding a package.

Reuse the existing CustomButton variants and CustomTextField, also exposed as AppTextField. AppIconButton, AppSearchField, FilterChipRow, AppBadge and UserAvatar complete the small controls. AppPageHeader and SectionHeader/AppSectionHeader provide hierarchy. GroupCard, OutingCard, PlaceCard and InvitationCard accept presentation data and callbacks only. Feature widgets own entities, Provider selection, localized labels, artwork/Hero selection and navigation.

Reuse AppShimmer skeletons, AppEmptyState, AppErrorState, AppSnackBar, AppAlert, AppBottomSheet and AppNetworkImage. Offline status is opt-in through AppOfflineIndicator; foreground sync remains silent globally. Do not add a parallel cache or connectivity layer. Preserve media:// resolution and account-scoped image caching.

The existing shell retains Home/Groups/Outings/Discover/Settings indexes and mounted tab state. The active violet pill slides directionally; tab content receives a restrained 8dp nudge. Inactive content has no focus, semantics, input or active tickers. High contrast uses an opaque outlined bar. Honor safe-area insets and reduced motion.

Future feature work composes small widgets under that feature's presentation/widgets directory. Components used by more than one feature belong in core/widgets. Keep networking, model decisions, lifecycle rules and mutation behavior out of shared rendering code. Phase 1 does not refactor or redesign all legacy feature screens.

Verification is static only for this phase. Phone/wide/foldable, light/dark, English/Arabic, keyboard and large-text rendering require later visual validation; no visual sign-off is claimed.


Phase 3 (2026-11-14) extends the same visual foundation to outing planning. OutingCard is shared by upcoming and active-vote adapters; active votes use intrinsically sized vertical content for long text. PlaceCard.option provides inline selectable rows and progress without nested card elevation. AppStepProgress renders route-local wizard progress with supplied localized labels. Separate detail sections compose shared covers, RSVP chips/avatars, voting, actual GPS attendance, location and management. State and mutation rules remain in existing providers/services/repositories; UI never resolves a vote winner. No dependency or visual language is replaced. Static/API verification only; visual theme/RTL/device sign-off remains outstanding by the task's explicit no-launch constraint.
