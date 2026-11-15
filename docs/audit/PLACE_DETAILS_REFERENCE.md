# Place details reference redesign — 2026-11-15

Implemented the supplied photo-led layout within Modern Social. Affected files: discover_place_details_page.dart, place_branch_picker.dart, save_place_button.dart and manual l10n.dart. Existing repository, catalog, bookmark, Hero and outing creation paths are reused. Added external map launch through the existing AppLauncher and an honest unavailable Reviews tab. No backend/database changes or operations.

Direction contract: Operate; photo first, readable rounded details surface, violet underline tabs and fixed actions. The provided reference pins the composition; existing palette/type/tokens govern both themes. The compact header and physical branch list support switching venue while preserving explicit planning. No fabricated rating, amenities or hours status.

Documentation Updates: DESIGN.md, FLUTTER_ARCHITECTURE.md and USER_SCENARIOS.md describe the current composition and feature boundaries. No diagrams changed because architecture/data flows are retained. Remaining mismatch with the reference: ratings/reviews/amenities are unavailable in the current model.

Verification limits: no Flutter launch, hot reload, device, runtime/widget/integration test or UI automation. Themes/locales, sizes/foldables, large text, keyboard/focus, gallery/tab/scroll/Hero behavior, authenticated saves, live branch paging and external maps were not exercised. Static check results recorded below.

Results: Dart MCP targeted analysis of all four affected Dart files returned "No errors". Scoped git diff --check passed. Dart formatting completed; the final formatter reported 0 changes, then exited with a telemetry-session file permission error outside the workspace. CLI analysis also reported "No issues found" before the same telemetry error. No runtime validation or visual sign-off is claimed.
