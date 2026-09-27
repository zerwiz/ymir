#!/usr/bin/env bash
# ymir-engine.sh — the DOOR to the engine (`src/ymir_runtime/`).
#
# The engine is one deep module with four verbs; this door is how a shell reaches
# it. It never re-implements a rule — it picks the interpreter, points PYTHONPATH
# at the tree, and hands the verb over:
#
#   ymir-engine.sh seat <id> --project <dir> [--harness h] [--model m] [--compat]
#   ymir-engine.sh status <id> [--window N] [--toon]
#   ymir-engine.sh send <id> "<text>"
#   ymir-engine.sh stop <id> [--remove-worktree]
#   ymir-engine.sh ensure | version
#
# Interpreters: a private venv ($YMIR_ENGINE_VENV, built by
# bin/ymir-engine-ensure.sh) when it exists, else the system python3. The engine
# is stdlib-only today, so both are the same engine.
#
# Exit codes are the engine's own, and 4 is the Strangler's hinge:
#   0 ran · 1 failed · 2 usage · 4 the engine will NOT own this errand — the
#   caller keeps its old road (never a silent downgrade, never a half-seat).
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV="${YMIR_ENGINE_VENV:-$HOME/.fleet/ymir-engine-venv}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ -d "$ROOT/src/ymir_runtime" ] || {
  printf 'error: engine package missing at %s/src/ymir_runtime\nhelp: this tree predates plan 58 Phase 1 — update it\n' "$ROOT" >&2
  exit 1
}

PY="${YMIR_ENGINE_PYTHON:-}"
if [ -z "$PY" ] && [ -x "$VENV/bin/python" ]; then PY="$VENV/bin/python"; fi
if [ -z "$PY" ]; then PY="$(command -v python3 2>/dev/null || true)"; fi
[ -n "$PY" ] || { printf 'error: no python3 — the engine cannot run\nhelp: bin/prereq-ensure.sh\n' >&2; exit 1; }

if [ "${1-}" = "ensure" ] && [ -x "$SCRIPT_DIR/ymir-engine-ensure.sh" ]; then
  "$SCRIPT_DIR/ymir-engine-ensure.sh" ensure || exit 1
  shift
  [ $# -eq 0 ] && exit 0
fi

export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"
# The engine must know the CODE tree it was launched from, which is not always
# what BROKK_HOME points at: a caller may point the home at a project so its
# worktrees land there, while the sibling bin/ doors stay in this tree.
export YMIR_ENGINE_ROOT="$ROOT"
exec "$PY" -m ymir_runtime "$@"
