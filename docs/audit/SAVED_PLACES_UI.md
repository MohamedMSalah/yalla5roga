# Saved place cards and My Saved filter

Added a shared bookmark button to Discover list, featured and nearby place cards. Confirmed saves use the existing per-user Neon API; filled icons indicate saved state. Controls serialize writes, show progress/errors and leave state unchanged on failure. My Saved now has a Places filter alongside its existing saved/draft views, with detail navigation, unsave, localized availability, loading/empty/retry states. Account changes clear saved state and ignore stale completions. Existing raw account snapshots cache the saved list; successful mutations revalidate it.

The existing saved-place datasource is reused. The backend saved list adds related place/category/vibe data in one query; no new endpoint or migration. Deploy/restart the updated backend with the Flutter changes for the hydrated list response.

Verification: TypeScript compilation passed. The disposable Neon/HTTP suite passed all 26 checks, including save, hydrated saved list and unsave. Dart analysis passed. No Flutter/emulator/device tests or visual runtime checks were run, preserving the owner's restriction.

Documentation Updates: PRODUCT_SCENARIOS, USER_SCENARIOS, BUSINESS_LOGIC, FLUTTER_ARCHITECTURE, BACKEND_ARCHITECTURE, API_CONTRACTS and PROJECT_STRUCTURE now describe bookmark state, API hydration, account/offline behavior and the saved Places view. Swagger adds the nested place field. No diagrams or database schema changed. Runtime layout and interaction remain unverified.
