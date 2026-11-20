#!/usr/bin/env -S uv run
# /// script
# dependencies = []
# ///
"""/install — stamp the smithy from the skill into the cwd. Idempotent.

Usage:
    uv run <skill>/scripts/install.py [--force]

Stamps: smidja/ (modules + starter smidja), smidja/smidja_data/prompt_engineering/
(4 starter agents), smidja/smidja_smidja_config/smidja.config.yaml, .env.sample,
.gitignore entries.
Existing files are skipped unless --force.
"""

import argparse
import os
import shutil
import sys
from pathlib import Path

TEMPLATES = Path(__file__).resolve().parent.parent / "templates"

GITIGNORE_ENTRIES = [
    "smidja/smidja_data/sessions/",
    "smidja/smidja_data/smidja.db*",
    ".env",
    # The smidja are Python, so importing smidja_modules writes bytecode next to it.
    # Chains that end in a commit phase call `git add -A`, so without this a
    # stamped repo commits its own .pyc files — 15 of them showed up in the
    # first repo that was ever installed into from scratch.
    "__pycache__/",
    "*.pyc",
]


def stamp(src: Path, dest: Path, force: bool, stamped: list, skipped: list) -> None:
    if src.is_dir():
        for child in sorted(src.iterdir()):
            if child.name == "__pycache__":
                continue
            stamp(child, dest / child.name, force, stamped, skipped)
        return
    if dest.exists() and not force:
        skipped.append(str(dest))
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    stamped.append(str(dest))


def ensure_gitignore(root: Path, stamped: list) -> None:
    gitignore = root / ".gitignore"
    existing = gitignore.read_text().splitlines() if gitignore.exists() else []
    missing = [e for e in GITIGNORE_ENTRIES if e not in existing]
    if missing:
        with gitignore.open("a") as f:
            f.write("\n# smidja runtime\n" + "\n".join(missing) + "\n")
        stamped.append(f"{gitignore} (+{len(missing)} entries)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="overwrite existing files")
    args = parser.parse_args()

    root = Path.cwd()
    stamped, skipped = [], []

    # Fail with a plain reason when the target cannot be written, rather than an
    # os.mkdir traceback mid-stamp.
    if not os.access(root, os.W_OK):
        print(f"error: {root} is not writable — run install.py from a writable repo root",
              file=sys.stderr)
        return 1

    try:
        stamp(TEMPLATES / "smidja", root / "smidja", args.force, stamped, skipped)
        stamp(TEMPLATES / "prompt_engineering",
              root / "smidja" / "smidja_data" / "prompt_engineering", args.force, stamped, skipped)
        stamp(TEMPLATES / "harness_engineering",
              root / "smidja" / "smidja_data" / "harness_engineering", args.force, stamped, skipped)
        stamp(TEMPLATES / "smidja.config.yaml",
              root / "smidja" / "smidja_smidja_config" / "smidja.config.yaml",
              args.force, stamped, skipped)
        stamp(TEMPLATES / "env.sample", root / ".env.sample", args.force, stamped, skipped)
        # The recipes are part of the operating experience, and several cookbooks
        # plus the run banner tell you to use them, so a stamped repo has to have
        # them. Skipped like any other file if the repo already has a justfile.
        stamp(TEMPLATES / "justfile", root / "justfile", args.force, stamped, skipped)
        ensure_gitignore(root, stamped)
    except PermissionError as exc:
        print(f"error: cannot write {exc.filename} — {exc.strerror}", file=sys.stderr)
        return 1

    print(f"smidja installed into {root}")
    print(f"  stamped: {len(stamped)} file(s)")
    for s in stamped:
        print(f"    + {s}")
    if skipped:
        print(f"  skipped (already exist, use --force to overwrite): {len(skipped)}")
    print("\nnext steps:")
    print("  1. cp .env.sample .env   # then set the key(s) your roster needs")
    print("  2. just demo             # two cheap read-only runs, end to end")
    print("  3. just sessions         # what just happened")
    print("  4. just obs              # the trace UI, needs bun")
    print("\n  no just? the raw form of step 2 is:")
    print("     uv run smidja/smidja_prompt.py \"say hello\" --agent scout")
    return 0


if __name__ == "__main__":
    sys.exit(main())
