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
#   bin/eindri-watch.sh retire <agent>
#   bin/eindri-watch.sh list
#   bin/eindri-watch.sh reconcile
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WHEN="$ROOT/.agents/backend/fm-procevent-when.sh"
RUNNER="$ROOT/.agents/backend/fm-procevent.sh"
INTERVAL="20"; STABLE="2"

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
  retire)
    [ $# -ge 1 ] || { echo "usage: eindri-watch.sh retire <agent>" >&2; exit 2; }
    "$WHEN" retire "$1"
    ;;
  list) "$RUNNER" list ;;
  reconcile) "$RUNNER" reconcile ;;
  *) echo "unknown command: $cmd (arm|retire|list|reconcile)" >&2; exit 2 ;;
esac