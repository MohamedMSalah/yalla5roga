# AI UI/UX agent setup

**Last verified:** 2026-11-09  
**Scope:** Project-local agent skills, MCP definitions, and UX guardrails for
the Flutter client. No backend, API contract, auth, or database logic was
changed.

## Environment validation

- Host: Windows, with Flutter/Dart, Node.js, Codex, Cursor, and Git available
  on `PATH`.
- App: Flutter/Dart (`flutter/pubspec.yaml` requires Dart `^3.13.3`), Provider
  / ChangeNotifier, feature-first Clean Architecture, Dio, Firebase Auth.
- Existing UI system: Material 3; `AppTheme`/`AppPalette`/`AppColors`; Inter
  (English) and Cairo (Arabic); `Responsive` token helpers; `L10n` and RTL;
  purpose-built shared widgets and animated transitions.

## Installed tools

| Tool | Version / source | Project location | Validation |
|---|---|---|---|
| Flutter Agent Plugins | Official `flutter/agent-plugins`; installed with pinned `skills@1.5.17` | `.agents/skills/` | Installed: 25 skills. |
| Impeccable | `4.8.1` skill; engine `0.1.19` (Windows x64); Apache-2.0 | `.agents/skills/impeccable/`, `.cursor/skills/impeccable/` | Installed; project hooks were generated. |
| Dart Tooling MCP | Official Dart server (`dart mcp-server`) | `.codex/config.toml`, `.cursor/mcp.json` | Server help runs successfully; Codex CLI recognizes it as enabled. |
| Figma MCP | Official remote endpoint | `.codex/config.toml`, `.cursor/mcp.json` | Defined but unauthenticated. |
| Refero MCP | Official Refero remote endpoint | `.codex/config.toml`, `.cursor/mcp.json` | Defined but unauthenticated. |

### Skills now available

The official bundle provides Flutter tasks for integration/widget testing,
widget previews, responsive layouts, layout fixes, JSON serialization,
architecture, localization, and declarative routing; plus Dart tasks for unit
tests, coverage, static analysis, runtime errors, mocks, package conflicts,
documentation, FFI, patterns, and CLI work. Run them only when their scope
matches the task.

`impeccable` provides design-system documentation/extraction and focused
`critique`, `audit`, `polish`, `layout`, `typeset`, `adapt`, `harden`, and
`animate` workflows. Invoke it in Codex as `$impeccable <command>`.

## MCP status and authorization

MCP definitions are project scoped so they do not affect other repositories.
They contain no tokens.

| Server | Current status | Manual action needed |
|---|---|---|
| Dart | Configured and recognized by Codex CLI | Reload Codex/Cursor so their tool menus rediscover the project configuration. |
| Figma | Configured, not connected | In Codex, install/connect the Figma plugin and complete Figma OAuth. A Dev/Full Figma seat and compatible plan may be required for the full remote capability. |
| Refero | Configured, not connected | Complete Refero OAuth when the client first requests it; access depends on the Refero account/plan. |

Impeccable installed project hook definitions in `.codex/hooks.json` and
`.cursor/hooks.json`. Codex requires an explicit project-hook approval in
`/hooks` after reload; Cursor hook support on Windows is not verified by the
upstream project. Do not treat a hook definition as an active hook until the
client reports it enabled.

Flutter dependency resolution and an analyzer health check were started with
the installed Flutter SDK. The analyzer process completed, but its host output
did not include a final diagnostic summary; do not interpret this setup check
as a clean-analysis claim. Run `flutter analyze --no-pub` in an interactive
terminal before treating the current working tree as analyzer-clean.

## Design-system guardrails

The reusable instructions are appended to `AGENTS.md`. They require agents to
inspect the current design language first, reuse theme/responsive/shared
components, preserve Provider/Clean Architecture, support English/Arabic RTL,
cover accessibility and all product states, add only purposeful motion, and
validate rendered states. They explicitly prohibit unapproved redesigns,
architecture changes, duplicate components, and generic AI patterns.

## Usage examples

```text
$impeccable critique flutter/lib/features/outings/presentation/pages/event_page.dart
Review this Flutter screen for Arabic RTL, text scaling, touch targets, and tablet behavior; preserve the existing design system.
Use Figma MCP to inspect the selected frame's variables and components before implementing the matching Flutter widget.
Use Dart MCP to analyze the Flutter project and run the relevant widget test.
```

## Sources and maintenance

- [Flutter Agent Plugins](https://github.com/flutter/agent-plugins) — official
  skills bundle and Dart MCP configuration.
- [Dart Tooling MCP Server](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server)
  — server behavior and client requirements.
- [Flutter AI tools](https://docs.flutter.dev/ai/tools) — official overview.
- [Figma MCP server](https://developers.figma.com/docs/figma-mcp-server/) and
  [Codex setup](https://help.figma.com/hc/en-us/articles/39888629089175-Codex-and-Figma-Set-up-the-MCP-server).
- [Refero MCP](https://refero.design/mcp) and its
  [official skill repository](https://github.com/referodesign/refero_skill).
- [Impeccable](https://github.com/pbakaus/impeccable) — Apache-2.0 design
  skill; review release notes before changing its pinned version.
- [Codex configuration](https://learn.chatgpt.com/docs/extend/mcp) and
  [project-local skills](https://learn.chatgpt.com/docs/build-skills).

To update the Flutter bundle, use the source-pinned installer documented by
Flutter (`npx skills@1.5.17 update`) from the repository root after reviewing
changes. To update Impeccable, review its release and run `npx impeccable
update`. Re-check this document, verify MCP connection state in the client,
and re-approve a changed Codex hook. Never put credentials in repository
configuration or commit them.
