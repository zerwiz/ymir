#!/usr/bin/env bash
# eindri-acclaim.sh — action half of the Eindri→Brokk wake bridge.
#
# Runs once when the when-adapter fires on a stable `true`: files the report
# durably (state/eindri-reports/<agent>.md), marks the agent as reported
# (state/eindri-done/<agent>.md — so a re-arm never refires instantly on old
# news), appends a wake to state/.wake-queue (surfaced by Sága's drain in the
# session digest), and sounds the desktop note. Idempotent via the marker.
#
# Usage: bin/eindri-acclaim.sh <agent> [<worktree-root>]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STATE="${BROKK_STATE_OVERRIDE:-$ROOT/state}"
AGENT="${1:-}"
WORKTREE="${2:-}"
[ -n "$AGENT" ] || { echo "usage: eindri-acclaim.sh <agent> [<worktree-root>]" >&2; exit 2; }

mkdir -p "$STATE/eindri-reports" "$STATE/eindri-done"
detail=""
if [ -f "$STATE/eindri-reports/$AGENT.md" ]; then
  detail="report filed at state/eindri-reports/$AGENT.md"
elif [ -n "$WORKTREE" ] && [ -f "$WORKTREE/REPORT.md" ]; then
  cp "$WORKTREE/REPORT.md" "$STATE/eindri-reports/$AGENT.md" 2>/dev/null || true
  detail="report filed from $WORKTREE/REPORT.md (state/eindri-reports/$AGENT.md)"
else
  detail="left working (herdr state flipped; read the pane: herdr agent read $AGENT)"
fi
printf 'eindri %s reported: %s\n' "$AGENT" "$detail" >>"$STATE/.wake-queue"
printf '%s %s: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT" "$detail" >"$STATE/eindri-done/$AGENT.md"
if [ -x "$SCRIPT_DIR/ymir-say.sh" ]; then
  "$SCRIPT_DIR/ymir-say.sh" note "Eindri $AGENT reported" >/dev/null 2>&1 || true
fi
printf 'eindri-acclaim[1]{agent,detail}:\n  "%s","%s"\n' "$AGENT" "$detail"