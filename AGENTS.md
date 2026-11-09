# Yalla 5roga — Agent Instructions

Every AI coding task for this repository **must** follow this workflow.

## 1. Entry point (always)

1. Read this file (`AGENTS.md`).
2. Identify which architectural layers the task touches.
3. Read **only** the relevant documentation (selective strategy below).
4. Use [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md) to locate implementation files.
5. Inspect **only** those source files (expand only when dependencies require it).
6. Do **not** invent product rules — [`docs/PRODUCT_SCENARIOS.md`](docs/PRODUCT_SCENARIOS.md) is the product authority.
7. Verify docs against source when they conflict; update docs in the **same task**.
8. Never silently introduce a new architectural pattern that conflicts with documented conventions (`docs/ARCHITECTURE_DECISIONS.md`).
9. Never claim something is implemented without verifying code.
10. Run relevant tests after implementation.
11. Keep documentation synchronized with the codebase (mandatory).

## 2. Canonical documentation

| Doc | Purpose |
|-----|---------|
| [`docs/PRODUCT_SCENARIOS.md`](docs/PRODUCT_SCENARIOS.md) | Approved product behavior |
| [`docs/PROJECT_OVERVIEW.md`](docs/PROJECT_OVERVIEW.md) | Product + stack overview |
| [`docs/SYSTEM_ARCHITECTURE.md`](docs/SYSTEM_ARCHITECTURE.md) | Components and communication |
| [`docs/SYSTEM_DESIGN.md`](docs/SYSTEM_DESIGN.md) | Technical workflow design |
| [`docs/USER_SCENARIOS.md`](docs/USER_SCENARIOS.md) | User journeys + coverage matrix |
| [`docs/FLUTTER_ARCHITECTURE.md`](docs/FLUTTER_ARCHITECTURE.md) | Flutter Clean Architecture |
| [`docs/BACKEND_ARCHITECTURE.md`](docs/BACKEND_ARCHITECTURE.md) | Express layers |
| [`docs/DATABASE_ARCHITECTURE.md`](docs/DATABASE_ARCHITECTURE.md) | Prisma / Neon schema |
| [`docs/API_CONTRACTS.md`](docs/API_CONTRACTS.md) | HTTP contracts |
| [`docs/BUSINESS_LOGIC.md`](docs/BUSINESS_LOGIC.md) | Rules vs implementation |
| [`docs/AUTHENTICATION_AND_AUTHORIZATION.md`](docs/AUTHENTICATION_AND_AUTHORIZATION.md) | AuthN/Z |
| [`docs/NOTIFICATIONS.md`](docs/NOTIFICATIONS.md) | Outbox, FCM, WhatsApp |
| [`docs/ARCHITECTURE_DECISIONS.md`](docs/ARCHITECTURE_DECISIONS.md) | ADRs |
| [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md) | Directory map |
| [`docs/audit/`](docs/audit/) | Compliance audits |

Historical notes: [`docs/system-design/`](docs/system-design/). Prefer canonical `docs/*.md` when they answer the question.

### Core triad for orientation

| Question | Document |
|----------|----------|
| How is the system designed? | `SYSTEM_DESIGN.md` (+ `SYSTEM_ARCHITECTURE.md`) |
| How does the user interact? | `USER_SCENARIOS.md` (+ `BUSINESS_LOGIC.md`) |
| Where is the code? | `PROJECT_STRUCTURE.md` |

## 3. Selective reading strategy

**Do not read every doc for every task.**

| Task type | Read first |
|-----------|------------|
| Flutter UI | `USER_SCENARIOS` (journey) + `FLUTTER_ARCHITECTURE` + structure map |
| Provider / repository | `FLUTTER_ARCHITECTURE` + `API_CONTRACTS` if network involved |
| Backend API | `BACKEND_ARCHITECTURE` + `API_CONTRACTS` |
| Database / Prisma | `DATABASE_ARCHITECTURE` + relevant `BUSINESS_LOGIC` |
| Auth | `AUTHENTICATION_AND_AUTHORIZATION` + backend/Flutter auth sections |
| Notifications | `NOTIFICATIONS` + related API/backend |
| Voting | `USER_SCENARIOS`, `SYSTEM_DESIGN`, `BUSINESS_LOGIC`, `DATABASE_ARCHITECTURE` as needed |
| Invitations | `USER_SCENARIOS`, `AUTHENTICATION_AND_AUTHORIZATION`, API/DB as needed |
| Attendance | `USER_SCENARIOS`, `BUSINESS_LOGIC`, `SYSTEM_DESIGN` |
| Outing lifecycle | `SYSTEM_DESIGN`, `BUSINESS_LOGIC`, `USER_SCENARIOS` |
| System-wide design | `SYSTEM_DESIGN` + `SYSTEM_ARCHITECTURE` |
| Cross-layer | `SYSTEM_ARCHITECTURE` + each directly affected doc |

Only expand reading when missing information or cross-dependencies require it.

## 4. Stack rules (non-negotiable)

- **Flutter** + Provider / ChangeNotifier, feature-first Clean Architecture, Dio.
- **Backend** Node.js + TypeScript + Express + Prisma.
- **Database** Neon PostgreSQL is the source of truth for application data.
- **Auth** Firebase Authentication; backend verifies Firebase ID tokens. Do **not** use Firebase as the application database.
- **Notifications** FCM via backend outbox / worker. No mock/demo data layers in Flutter.
- Do not introduce a different architectural pattern without an ADR in `ARCHITECTURE_DECISIONS.md`.

## 5. Documentation update mapping (same task)

| Implementation change | Update |
|-----------------------|--------|
| Overall system architecture | `SYSTEM_ARCHITECTURE.md` |
| Technical system design / workflows | `SYSTEM_DESIGN.md` |
| User journeys / interaction flows | `USER_SCENARIOS.md` |
| Flutter architecture | `FLUTTER_ARCHITECTURE.md` |
| Backend architecture | `BACKEND_ARCHITECTURE.md` |
| Database schema | `DATABASE_ARCHITECTURE.md` |
| API contracts | `API_CONTRACTS.md` |
| Business rules | `BUSINESS_LOGIC.md` **and** affected `USER_SCENARIOS.md` sections |
| Voting / invitation / attendance / lifecycle workflows | `SYSTEM_DESIGN.md`, `BUSINESS_LOGIC.md`, `USER_SCENARIOS.md` (+ DB/API if needed) |
| Authentication / authorization | `AUTHENTICATION_AND_AUTHORIZATION.md` |
| Notifications | `NOTIFICATIONS.md` |
| Architectural decisions | `ARCHITECTURE_DECISIONS.md` |
| Folders / organization | `PROJECT_STRUCTURE.md` |
| Product scope | `PROJECT_OVERVIEW.md` / `PRODUCT_SCENARIOS.md` (owner-approved) |

If multiple areas change, update **all** affected files before finishing. Never postpone docs.

### Final task report must include

**Documentation Updates** — files updated; what changed; diagrams updated?; remaining inconsistencies. If none required, say why.

## 6. Token efficiency

- Do not scan the entire repository by default.
- Do not read all documentation by default.
- Prefer structure map → targeted files.
- Prefer correctness over savings when dependencies are unclear.

## 7. Compliance

Any implementation that conflicts with `docs/PRODUCT_SCENARIOS.md` is a **product compliance issue** until the product owner updates that document.

Critical distinctions:

- Place voting ≠ attendance.
- Firebase Auth ≠ application database.
- Owner is outing-scoped (`created_by`), not a global role.
- Backend owns winner / closure / tie-break / cancel / authZ / notification triggers.

## 8. UI/UX quality workflow (Flutter)

For any Flutter presentation change, treat the existing application as the
design authority before proposing or writing UI. Do not redesign a screen,
replace the visual language, or add a dependency without explicit approval.

1. Read the relevant journey in `docs/USER_SCENARIOS.md`, this file, and
   `docs/FLUTTER_ARCHITECTURE.md`; then inspect the target screen and the
   reusable widgets/tokens it already uses.
2. Reuse `AppTheme`, `AppPalette`, `AppColors`, `Responsive`, and
   `core/widgets/` before creating local colors, spacing, controls, or motion.
   Preserve Material 3, Inter (English), Cairo (Arabic), light/dark themes,
   and the current provider/feature-first architecture.
3. Preserve both English and Arabic behavior. Use `L10n`, logical directional
   APIs, and `Directionality`; verify RTL ordering, Arabic-Indic numbers where
   existing formatters require them, and mirrored navigation/animations.
4. Design task flows for loading, empty, error, offline, keyboard, long-text,
   and narrow/wide/foldable states. Use `Responsive` and its content-width
   limits rather than device-specific constants.
5. Meet mobile usability basics: semantic labels for non-text controls,
   readable contrast, focus order, `textScaler` resilience, and at least a
   48dp effective touch target unless an established component documents an
   intentional exception.
6. Keep hierarchy purposeful: one primary action per task state, clear
   heading/body contrast, token-based spacing, and concise localized copy.
   Avoid generic AI visual tropes, arbitrary gradients, duplicate cards, and
   decorative motion.
7. Motion must clarify a state or navigation change, respect platform motion
   settings where supported, and use the existing transition/animation widgets
   before adding a new pattern.
8. Before completion, run the relevant analyzer/tests and visually inspect the
   target at phone, wide/foldable, light/dark, and English/Arabic states when
   practical. Report any states that could not be exercised.

### Agent tools

- Use the installed Flutter/Dart skills selectively. Do not apply the
  localization or declarative-routing setup skills to this established app:
  it uses manual `L10n` and imperative GetX navigation by design.
- Use the Dart MCP server for analyzer diagnostics, package-aware symbol
  lookup, test execution, and running-app inspection when connected.
- If a Figma design is provided, authenticate the Figma MCP server and inspect
  its variables/components before translating a frame. Do not infer a Figma
  design system from a screenshot alone.
- Use Refero research only to inform patterns, never to copy product content
  or replace the app's established design language.
- Use `$impeccable` for a focused UI critique, audit, polish, responsive,
  accessibility, or motion task. It must preserve the existing design unless
  the user has explicitly approved a redesign.
