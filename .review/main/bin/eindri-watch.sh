#!/usr/bin/env bash
# eindri-watch.sh — the control door on the Eindri→Brokk wake bridge.
#
# One when-source per seated smith, spun on the Norns' loom (.agents/backend/
# fm-procevent-when.sh + the runner's reconcile). When a smith reports (his
# REPORT.md lands or herdr shows him left working), the bridge fires the
# acclaim: the wake lands in state/.wake-queue and the session digest shows it.
# Brokk handles the wake, reads the report, then re-arms for the next errand.
#
#   bin/eindri-watch.sh arm [--interval N] [--stable N] <agent> [<worktree>]
#   bin/eindri-watch.sh arm-silence <agent> [--window N] [--interval N] [--stable N]
#   bin/eindri-watch.sh retire <agent>
#   bin/eindri-watch.sh list
#   bin/eindri-watch.sh reconcile
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WHEN="$ROOT/.agents/backend/fm-procevent-when.sh"

# The spec must record a STABLE adapter path, never the caller's tree. An arm run
# from a Yggdrasil worktree wrote the WORKTREE's fm-procevent-when.sh into the
# spec; when the worktree was cleaned, the runner kept a path that no longer
# existed. Resolve to the MAIN tree via git's common dir, so an arm from any
# worktree records the same adapter.
if command -v git >/dev/null 2>&1 && [ -d "$ROOT/.git" -o -f "$ROOT/.git" ]; then
  _common="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)"
  if [ -n "$_common" ]; then
    _main="$(cd "$ROOT" && cd "$(dirname "$_common")" 2>/dev/null && pwd)"
    # Inside a worktree this resolves to the MAIN tree; in the main tree it
    # resolves to itself, and the `!=` keeps us idempotent.
    if [ -n "$_main" ] && [ "$_main" != "$ROOT" ] && [ -x "$_main/.agents/backend/fm-procevent-when.sh" ]; then
      ROOT="$_main"; WHEN="$ROOT/.agents/backend/fm-procevent-when.sh"
      # The condition/action scripts are recorded in the SPEC too — pin them to
      # the same stable tree, or cleaning the worktree breaks the watch.
      [ -x "$_main/bin/eindri-seen.sh" ] && SCRIPT_DIR="$_main/bin"
    fi
  fi
  unset _common _main
fi

# The spec must live in the OPERATOR'S HOME, never beside whichever tree the
# caller happens to stand in. fm-procevent-when.sh defaults its state to
# FM_HOME/state = <script dir>/../state, so an arm run from a Yggdrasil worktree
# wrote the spec INTO THE WORKTREE — where the runner never looks, and which is
# deleted on cleanup. That is how when-huginn.spec was thrown away while Huginn's
# report sat unnoticed (2026-09-23). Pin it to the hoard, and the runner reads
# the same place wherever it was started from.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
hoard_state_dir _HS 2>/dev/null && FM_STATE_OVERRIDE="${FM_STATE_OVERRIDE:-$_HS/procevent}"
export FM_STATE_OVERRIDE
RUNNER="$ROOT/.agents/backend/fm-procevent.sh"
INTERVAL="20"; STABLE="2"

# Arm the silence bridge for one agent (D8). The when-name is <agent>-silent
# so it never collides with the report-when <agent>; the condition is
# eindri-heartbeat.sh (exit 0 = SILENT), the action eindri-acclaim-silent.sh
# (wakes Brokk with id, elapsed, last line; idempotent per silence epoch).
# The window is seconds since the worker's last status append.
arm_silence() {
  local name= window=1800 interval=20 stable=2
  while [ $# -gt 0 ] && [ "${1#--}" != "$1" ]; do
    case "$1" in
      --window) window="${2-}"; shift 2 ;;
      --window=*) window=${1#--window=}; shift ;;
      --interval) interval="${2-}"; shift 2 ;;
      --stable) stable="${2-}"; shift 2 ;;
      *) echo "unknown option $1" >&2; exit 2 ;;
    esac
  done
  [ $# -ge 1 ] || { echo "usage: eindri-watch.sh arm-silence <agent> [--window N] [--interval N] [--stable N]" >&2; exit 2; }
  name="${1-}"
  case "$window" in ''|*[!0-9]*) echo "error: --window must be a number of seconds" >&2; exit 2 ;; esac
  "$WHEN" arm "${name}-silent" --interval "$interval" --stable "$stable" \
    --condition bash "$SCRIPT_DIR/eindri-heartbeat.sh" "$name" --window "$window" \
    --action bash "$SCRIPT_DIR/eindri-acclaim-silent.sh" "$name"
  printf 'eindri-watch[1]{agent,source,window}:
  "%s","when-%s-silent","%s"\n' "$name" "$name" "$window"
}

case "${1-}" in
  ""|-h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

cmd="${1-}"; shift || true
case "$cmd" in
  arm)
    while [ $# -gt 0 ] && [ "${1#--}" != "$1" ]; do
      case "$1" in
        --interval) INTERVAL="${2-}"; shift 2 ;;
        --stable) STABLE="${2-}"; shift 2 ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
      esac
    done
    [ $# -ge 1 ] || { echo "usage: eindri-watch.sh arm [--interval N] [--stable N] <agent> [<worktree>]" >&2; exit 2; }
    name="${1-}"; wt="${2-}"
    "$WHEN" arm "$name" --interval "$INTERVAL" --stable "$STABLE" \
      --condition bash "$SCRIPT_DIR/eindri-seen.sh" "$name" "$wt" \
      --action bash "$SCRIPT_DIR/eindri-acclaim.sh" "$name" "$wt"
    # arm the silence bridge too (D8): a worker with no status append inside
    # its window must not look like a thinking one. Best-effort: a missing
    # heartbeat script (an older tree) must not fail the report arm.
    if [ -x "$SCRIPT_DIR/eindri-heartbeat.sh" ] && [ -x "$SCRIPT_DIR/eindri-acclaim-silent.sh" ]; then
      arm_silence "$name" --window "${EINDRI_SILENT_WINDOW:-1800}" --interval "$INTERVAL" --stable "$STABLE" >/dev/null 2>&1 || true
    fi
    state=$(herdr agent list 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for a in d['result']['agents']:
        if (a.get('name')==sys.argv[1]): print(a.get('agent_status','unknown'))
except Exception: pass
" "$name" 2>/dev/null)
    printf 'eindri-watch[1]{agent,state,source}:\n  "%s","%s","when-%s"\n' "$name" "${state:-unknown}" "$name"
    ;;
  arm-silence)
    arm_silence "$@"
    ;;
  retire)
    [ $# -ge 1 ] || { echo "usage: eindri-watch.sh retire <agent>" >&2; exit 2; }
    "$WHEN" retire "$1"
    # a silence bridge, when armed, dies with the same name prefix
    "$WHEN" retire "${1}-silent" 2>/dev/null || true
    ;;
  list) "$RUNNER" list ;;
  reconcile) "$RUNNER" reconcile ;;
  *) echo "unknown command: $cmd (arm|arm-silence|retire|list|reconcile)" >&2; exit 2 ;;
esac