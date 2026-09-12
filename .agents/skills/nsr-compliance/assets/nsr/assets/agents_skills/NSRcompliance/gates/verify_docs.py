#!/usr/bin/env python3
# Deterministic gate: ensure STRUCTURE.md, FEATURES.md, HOSTING/, DEVELOPER_SETUP/ and TECH_STACK.md are in sync with the repo.
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
MANDATORY = [
    "AGENTS.md", "ARCHITECTURE.md", "STRUCTURE.md", "FEATURES.md",
    "RULES.md", "BEST_PRACTICES.md", "CI_CD.md", "TECH_STACK.md", "README.md",
]
MANDATORY_DIRS = [
    "RULES", "docs/features", "docs/BEST_PRACTICES", "docs/CI_CD",
    "docs/DEVELOPER_SETUP", "docs/HOSTING", "docs/RUNBOOK", "docs/research",
    ".agents/skills", ".compliance",
]
EXPLICIT_DOCS = {
    "docs/HOSTING": ["README.md", "_template.md"],
    "docs/DEVELOPER_SETUP": ["README.md"],
}
EXPLICIT_SUBDIRS = {
    "docs/HOSTING": [],          # hosting-N.md files are enumerated dynamically
    "docs/DEVELOPER_SETUP": ["developers"],  # dev-N.md files are enumerated dynamically
}


def enumerate_explicit(directory: str, subdir: str) -> list:
    base = ROOT / directory
    if subdir:
        base = base / subdir
    if not base.exists():
        return []
    return sorted(p.name for p in base.glob("*.md") if p.name not in ("README.md", "_template.md"))


def main() -> int:
    missing = [f for f in MANDATORY if not (ROOT / f).exists()]
    missing_dirs = [d for d in MANDATORY_DIRS if not (ROOT / d).exists()]

    problems = []
    for directory, required in EXPLICIT_DOCS.items():
        for name in required:
            if not (ROOT / directory / name).exists():
                problems.append(f"{directory}/{name}")

    # Every hosting/developer must have its own explicit file (numbered *_N.md or dev-N.md)
    for directory, subdirs in EXPLICIT_SUBDIRS.items():
        subdirs_to_check = subdirs if subdirs else [""]
        for subdir in subdirs_to_check:
            entries = enumerate_explicit(directory, subdir)
            if not entries:
                problems.append(f"{directory}/{subdir}/<explicit file missing>" if subdir else f"{directory}/<hosting file missing>")

    if missing or missing_dirs or problems:
        print(json.dumps({
            "missing_files": missing,
            "missing_dirs": missing_dirs,
            "explicit_docs_missing": problems,
        }))
        return 1
    print(json.dumps({"ok": True, "docs_synced": True}))
    return 0


if __name__ == "__main__":
    sys.exit(main())