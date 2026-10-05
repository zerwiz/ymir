#!/usr/bin/env bash
# rail-resolve.sh — the DOOR to the living rail resolver (plan 51, Parts 9a/9b/9c).
#
# The Allfather's doctrine: models come from whichever strong box is CONNECTED at
# the moment — heimdall · whynot · omarchy. This door is how a shell reaches the
# engine's ONE resolver of that question (`src/ymir_runtime/fleet/rail.py`). It
# never re-implements a rule: it resolves the operator's home, points PYTHONPATH
# at the tree, and hands the verb over. Every surface that states a rail URL calls
# THIS, so none of them restates one.
#
#   rail-resolve.sh resolve [alias]   # the serving OpenAI URL + the key REFERENCE
#   rail-resolve.sh status            # the ranked live set (a dropped box shows)
#   rail-resolve.sh resolve --json    # machine-readable (callers parse this)
#   rail-resolve.sh --version
#
# Registry (read at runtime; NEVER shipped): $YMIR_HOME/hodd/data/fleet.json.
# The strong boxes are the registry's ordered `rails` list, else its `ear` list,
# else its `forge` hosts — a box the registry does not name is never invented.
# The shared key is a REFERENCE (env `LLAMA_SWAP_API_KEY`), never a value here.
#
# Exit: 0 answered · 1 declined (no live rail, or no live rail serves the alias)
#       2 usage · 3 the engine or an interpreter is missing.
set -u

VERSION="1.0.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The ONE resolver (Rule 07): env → the recorded choice, through `bin/vault/hoard-lib.sh`.
# This door never restates a path; when no home can be resolved the module reports
# a declined answer rather than guessing one.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null || true; fi
export YMIR_HOME="${YMIR_HOME:-${YMIR_HOME_ROOT:-}}"
export YMIR_HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
export YMIR_FLEET_REGISTRY="${YMIR_FLEET_REGISTRY:-$YMIR_HOME/hodd/data/fleet.json}"

[ -d "$ROOT/src/ymir_runtime/fleet" ] || {
  printf 'error: the fleet module is missing at %s/src/ymir_runtime/fleet\n' "$ROOT" >&2
  printf 'help: this tree predates the living rail resolver — update it\n' >&2
  exit 3
}

PY="${YMIR_ENGINE_PYTHON:-}"
VENV="${YMIR_ENGINE_VENV:-$HOME/.fleet/ymir-engine-venv}"
if [ -z "$PY" ] && [ -x "$VENV/bin/python" ]; then PY="$VENV/bin/python"; fi
if [ -z "$PY" ]; then PY="$(command -v python3 2>/dev/null || true)"; fi
[ -n "$PY" ] || { printf 'error: no python3 — the rail resolver cannot run\nhelp: bin/engine/prereq-ensure.sh\n' >&2; exit 3; }

export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"
export YMIR_ENGINE_ROOT="$ROOT"
exec "$PY" -m ymir_runtime.fleet "$@"
