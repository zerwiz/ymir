#!/usr/bin/env bash
# install.sh — build this release of the smithy in place (the app contract; Ymir's bin/apps/apps.sh runs it).
#
#   install.sh          the viewer (bun install + build → apps/visualizer/dist), the agents' prompts
#                       stamped into the engine, the `smidja` command checked
#   install.sh --check  change nothing; exit 1 naming what is not right
#
# Alone, from a clone: ./install.sh, then ./activate.sh puts `smidja` on PATH and seats the MCP.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
case "$HERE" in */ymir-runtime/apps/*|*/ymir/apps/*)
  printf 'error: refusing to build inside a Ymir tree (%s) — an installed app has its own home\n' "$HERE" >&2; exit 1 ;;
esac
if ! command -v bun >/dev/null 2>&1 && [ -x "$HOME/.bun/bin/bun" ]; then PATH="$HOME/.bun/bin:$PATH"; fi
VIZ="$HERE/apps/visualizer"

check() {
  local bad=0
  command -v uv >/dev/null 2>&1 || { printf 'error: uv is not installed — the chains are uv scripts\n' >&2; bad=1; }
  command -v "${PI_PATH:-pi}" >/dev/null 2>&1 || printf 'warn: pi is not on PATH — the smithy has no worker until it is\n' >&2
  [ -f "$VIZ/dist/index.html" ] || { printf 'error: the viewer is not built (apps/visualizer/dist) — run ./install.sh\n' >&2; bad=1; }
  # The engine is the templates, byte for byte: the installer stamps projects from templates/, and a
  # drifted engine is work the next stamp drops (the drift found 2026-11-18).
  if ! diff -rq -x smidja_data -x smidja_smidja_config -x __pycache__ "$HERE/engine" "$HERE/templates/smidja" >/dev/null 2>&1; then
    printf 'error: engine/ has drifted from templates/smidja — fold the change into both\n' >&2; bad=1
  fi
  [ -f "$HERE/engine/smidja_data/prompt_engineering/planner/system.md" ] \
    || { printf 'error: the agents have no prompts (engine/smidja_data) — run ./install.sh\n' >&2; bad=1; }
  python3 "$HERE/scripts/smidja" chains --json >/dev/null 2>&1 \
    || { printf 'error: the smidja command does not answer (scripts/smidja chains)\n' >&2; bad=1; }
  [ "$bad" = 0 ] && printf 'smidja: ready (viewer built, engine = templates, prompts present, the command answers)\n'
  return "$bad"
}

if [ "${1-}" = --check ]; then check; exit $?; fi

command -v bun >/dev/null 2>&1 || { printf 'error: bun is not installed — the viewer is a bun build (https://bun.sh)\n' >&2; exit 1; }
(cd "$VIZ" && bun install --frozen-lockfile >/dev/null && bun run build >/dev/null)
# The agents' prompts and harness extensions: every MISSING file from templates/, never overwriting one.
python3 - "$HERE" <<'PY'
import shutil, sys
from pathlib import Path
here = Path(sys.argv[1])
for part in ("prompt_engineering", "harness_engineering"):
    src = here / "templates" / part
    for f in src.rglob("*"):
        if f.is_file():
            dest = here / "engine" / "smidja_data" / part / f.relative_to(src)
            if not dest.exists():
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, dest)
PY
mkdir -p "${YMIR_APP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/smidja}" "${YMIR_APP_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/smidja}"
printf 'smidja: built — ./activate.sh seats `smidja` on PATH and the Smíðja MCP in every harness\n'
