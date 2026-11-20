#!/usr/bin/env bash
# ymir-state.sh — the DOOR to the engine's STATE module (`src/ymir_runtime/state/`).
#
# The state crafts (locks · runes · envelopes · queues) live in one Python
# module; this door is how a shell reaches them. It never re-implements a rule —
# it picks the interpreter, points PYTHONPATH at the tree, and hands the verb over:
#
#   ymir-state.sh lock state-dir | lock-path | owner | pid-alive <pid> [expect]
#   ymir-state.sh lock session-pid --shell-pid N | owned | acquire | release | reap
#   ymir-state.sh runes append <actor> <event> --message M [--order O] [--realm R]
#   ymir-state.sh queue append <kind> <key> <payload> [--queue P]
#   ymir-state.sh queue keys <kind> [--queue P] | queue read [--queue P]
#
# Exit codes are the module's own: 0 ran (condition true) · 1 ran (condition
# false / IO failed) · 2 usage. `bin/vault/gleipnir-lock-lib.sh` and
# `bin/records/runes-append.sh` are thin shims over this door; a body added in bash
# would be the second implementation this door exists to remove.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
VENV="${YMIR_ENGINE_VENV:-$HOME/.fleet/ymir-engine-venv}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ -d "$ROOT/src/ymir_runtime/state" ] || {
  printf 'error: state module missing at %s/src/ymir_runtime/state\nhelp: this tree predates plan 58 — update it\n' "$ROOT" >&2
  exit 1
}

PY="${YMIR_ENGINE_PYTHON:-}"
if [ -z "$PY" ] && [ -x "$VENV/bin/python" ]; then PY="$VENV/bin/python"; fi
if [ -z "$PY" ]; then PY="$(command -v python3 2>/dev/null || true)"; fi
[ -n "$PY" ] || { printf 'error: no python3 — the state module cannot run\nhelp: bin/engine/prereq-ensure.sh\n' >&2; exit 1; }

export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"
export YMIR_ENGINE_ROOT="$ROOT"
exec "$PY" -m ymir_runtime.state "$@"
