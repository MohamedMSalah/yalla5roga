"""Read-only reference/inventory audit; does not launch Flutter or contact services."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs/audit/PHASE_8_STRUCTURE_RESULTS.json"
SKIP = (".agents/", ".cursor/skills/", ".cursor/agents/", "backend/.cursor/skills/")


def contrast_checks() -> list[dict]:
    """Check the opaque semantic text/fill pairs used by this polish pass."""
    primitives = (ROOT / "flutter/lib/core/theme/app_colors.dart").read_text()
    palette = (ROOT / "flutter/lib/core/theme/app_palette.dart").read_text()
    colors = {key: int(value, 16) for key, value in re.findall(
        r"static const (\w+) = Color\(0x([A-Fa-f0-9]+)\)", primitives)}

    def color(expression: str) -> int:
        if expression == "Colors.white":
            return 0xFFFFFFFF
        if expression.startswith("AppColors."):
            return colors[expression.split(".")[1]]
        return int(re.search(r"0x([A-Fa-f0-9]+)", expression)[1], 16)

    def luminance(value: int) -> float:
        assert value >> 24 == 255, "Only opaque color pairs are measured"
        channels = [(value >> shift & 255) / 255 for shift in (16, 8, 0)]
        linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
        return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))

    results = []
    for theme, block in re.findall(r"static const (light|dark) = AppPalette\((.*?)\n  \);", palette, re.S):
        roles = {key: color(value) for key, value in re.findall(r"(\w+): ([^\n]+),", block)}
        for key, dark, light in re.findall(
            r"Color get (\w+) =>\s*isDark \? const Color\(0x([A-Fa-f0-9]+)\) : const Color\(0x([A-Fa-f0-9]+)\)", palette):
            roles[key] = int(dark if theme == "dark" else light, 16)
        for foreground, background in [
            ("brandStrong", "brandSoft"), ("brandStrong", "surface"),
            ("brandStrong", "background"), ("success", "successSoft"),
            ("danger", "dangerSoft"), ("warning", "warningSoft"),
            ("chipActiveText", "chipActive"), ("textMuted", "surface"),
        ]:
            values = sorted([luminance(roles[foreground]), luminance(roles[background])])
            ratio = (values[1] + 0.05) / (values[0] + 0.05)
            results.append({"theme": theme, "foreground": foreground, "background": background, "ratio": round(ratio, 2), "passes_4_5": ratio >= 4.5})
    assert len(results) == 16
    return results


def main() -> None:
    output = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
    )
    paths = sorted({Path(name.decode()) for name in output.split(b"\0") if name})
    files = [p for p in paths if (ROOT / p).is_file() and not p.as_posix().startswith(SKIP)]
    unresolved = []
    pages = []
    imports_checked = 0
    doc_hashes: dict[str, list[str]] = {}
    instruction_files = []
    for path in files:
        name = path.as_posix()
        if path.suffix not in {".dart", ".ts", ".mjs", ".md", ".mdc"}:
            continue
        content = (ROOT / path).read_text(encoding="utf-8-sig")
        if path.suffix == ".dart":
            for match in re.finditer(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]", content):
                target = match[1]
                if target.startswith("package:yalla_5roga/"):
                    resolved = ROOT / "flutter/lib" / target.split("/", 1)[1]
                elif ":" not in target:
                    resolved = (ROOT / path).parent / target
                else:
                    continue
                imports_checked += 1
                if not resolved.is_file():
                    unresolved.append({"file": name, "reference": target})
        elif path.suffix in {".ts", ".mjs"}:
            for match in re.finditer(r"(?:from\s*|import\s*\()['\"](\.[^'\"]+)['\"]", content):
                target = (ROOT / path).parent / match[1]
                candidates = [target, target.with_suffix(".ts"), target.with_suffix(".mts")]
                imports_checked += 1
                if not any(p.is_file() for p in candidates):
                    unresolved.append({"file": name, "reference": match[1]})
        if name.startswith("flutter/lib/features/") and "/pages/" in name and path.suffix == ".dart":
            pages.append({
                "path": name,
                "lines": len(content.splitlines()),
                "feature_widget_imports": len(re.findall(r"import .*presentation/widgets/", content)),
                "shared_widget_imports": len(re.findall(r"import .*core/widgets/", content)),
                "direct_sdk_imports": re.findall(r"import ['\"]package:(?:dio|http|firebase_[^/]+|socket_io_client)/[^'\"]+", content),
                "review": "Source inventory only; rendered/runtime states NOT RUN",
            })
        if name.startswith("docs/") and path.suffix == ".md":
            digest = hashlib.sha256(content.encode()).hexdigest()
            doc_hashes.setdefault(digest, []).append(name)
        if path.name in {"AGENTS.md", "CLAUDE.md", "GEMINI.md", ".cursorrules", ".clinerules"} or path.suffix == ".mdc":
            instruction_files.append(name)

    root_rules = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    headings = [
        "Project Overview", "Technology Stack", "Flutter Architecture & Rules",
        "Backend Architecture & Rules", "Database & Prisma Rules", "API Contracts",
        "Authentication & Authorization", "Socket.IO & Real-Time Rules",
        "Caching & Offline Rules", "UI/UX & Reusable Widgets", "Coding Standards",
        "Testing & Verification Restrictions", "Agent Workflow & Safety Rules",
    ]
    assert all(f"## {title}" in root_rules for title in headings)
    assert [p for p in instruction_files if p.endswith("AGENTS.md")] == ["AGENTS.md"]
    assert [p for p in instruction_files if p.endswith(".mdc")] == [".cursor/rules/global.mdc"]
    assert "@AGENTS.md" in (ROOT / ".cursor/rules/global.mdc").read_text()
    assert (ROOT / "backend/.specify/memory/../../../AGENTS.md").resolve().is_file()

    moved = json.loads((ROOT / "docs/audit/PHASE_8_FILE_MOVES.json").read_text())
    stale_move_refs = []
    for row in moved:
        if "from" not in row:
            continue
        assert not (ROOT / row["from"]).exists()
        assert (ROOT / row["to"]).is_file()
        old_basename = Path(row["from"]).name
        for path in files:
            if path.suffix not in {".md", ".mdc", ".json", ".yaml", ".yml", ".toml", ".ps1"}:
                continue
            if path.as_posix().startswith("docs/audit/PHASE_"):
                continue  # Movement manifests/historical evidence name old paths deliberately.
            content = (ROOT / path).read_text(encoding="utf-8-sig")
            if row["from"] in content or f"`{old_basename}`" in content:
                stale_move_refs.append(path.as_posix())

    report = {
        "mode": "Filesystem/source checks only; no app/tests/services/database operations",
        "project_files_inventoried_excluding_tool_packages": len(files),
        "local_source_imports_checked": imports_checked,
        "unresolved_imports": unresolved,
        "instruction_files": instruction_files,
        "canonical_rule_sections": headings,
        "stale_moved_document_references": sorted(set(stale_move_refs)),
        "byte_identical_document_groups": [group for group in doc_hashes.values() if len(group) > 1],
        "screens": pages,
        "static_semantic_text_color_pairs": contrast_checks(),
        "tool_configuration": "Retained Codex/Cursor MCP/hooks, installed skills/subagents, Spec Kit templates/manifests/settings; no Claude/Gemini setup present",
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pages": len(pages), "imports": imports_checked, "unresolved": len(unresolved), "stale_move_refs": len(stale_move_refs)}))
    if unresolved or stale_move_refs or not all(row["passes_4_5"] for row in report["static_semantic_text_color_pairs"]):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
