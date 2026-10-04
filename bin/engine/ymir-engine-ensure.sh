#!/usr/bin/env bash
# ymir-engine-ensure.sh — materialize the engine's private python home.
#
# The engine's four verbs are stdlib-only; Phase 7's config layer (load-with-schema)
# declared the tree's first real dependencies (jsonschema, PyYAML), and the moment
# a dependency is declared the venv must appear WITHOUT the tree changing: a
# private, machine-local venv is built here, never committed (the repo ships
# source; the seat builds its own home).
#
#   ymir-engine-ensure.sh          # ensure (idempotent, cheap)
#   ymir-engine-ensure.sh status   # report only, change nothing
#   ymir-engine-ensure.sh --version
#
# Venv location: $YMIR_ENGINE_VENV → $HOME/.fleet/ymir-engine-venv (the fleet's
# own seat-space convention, beside ~/.fleet/well-venv — never the code tree).
#
# Exit: 0 ready · 1 could not provision · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$ROOT/src/pyproject.toml"
VENV="${YMIR_ENGINE_VENV:-$HOME/.fleet/ymir-engine-venv}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  status|ensure) ACTION="${1:-ensure}" ;;
  *) printf 'error: unknown flag %s\nhelp: bin/engine/ymir-engine-ensure.sh [status|ensure]\n' "$1" >&2; exit 2 ;;
esac

[ -r "$PROJECT" ] || { printf 'error: engine project missing: %s\n' "$PROJECT" >&2; exit 1; }

# The declared dependency list, read without a TOML parser (the engine must
# still answer on a bare python3): the [project] block's `dependencies = [...]`.
deps="$(awk '
  /^\[project\]/ { inside = 1; next }
  /^\[/         { inside = 0 }
  inside && /^dependencies[[:space:]]*=/ { print; exit }
' "$PROJECT" | sed -E 's/^dependencies[[:space:]]*=[[:space:]]*\[//; s/\][[:space:]]*$//' | tr -d '"'"'"' \t')"

if [ -z "$deps" ]; then
  printf 'engine-ensure[1]{venv,state,deps}:\n  "%s","not needed (stdlib only)","0"\n' "$VENV"
  exit 0
fi

if [ "$ACTION" = status ]; then
  if [ -x "$VENV/bin/python" ]; then
    printf 'engine-ensure[1]{venv,state,deps}:\n  "%s","present","%s"\n' "$VENV" "$(printf '%s' "$deps" | tr ',' ' ' | wc -w | tr -d ' ')"
  else
    printf 'engine-ensure[1]{venv,state,deps}:\n  "%s","ABSENT — run ensure","%s"\n' "$VENV" "$deps"
  fi
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { printf 'error: python3 not on PATH\nhelp: bin/prereq-ensure.sh\n' >&2; exit 1; }
if [ ! -x "$VENV/bin/python" ]; then
  mkdir -p "$(dirname "$VENV")" || { printf 'error: cannot create %s\n' "$(dirname "$VENV")" >&2; exit 1; }
  python3 -m venv "$VENV" >/dev/null 2>&1 || { printf 'error: python3 -m venv failed at %s\n' "$VENV" >&2; exit 1; }
fi
"$VENV/bin/pip" -q install -e "$ROOT/src" >/dev/null 2>&1 || {
  printf 'error: pip install -e %s/src failed\n' "$ROOT" >&2; exit 1
}
printf 'engine-ensure[1]{venv,state,deps}:\n  "%s","provisioned","%s"\n' "$VENV" "$deps"
