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

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
AGENT="${1:-}"
WORKTREE="${2:-}"
[ -n "$AGENT" ] || { echo "usage: eindri-acclaim.sh <agent> [<worktree-root>]" >&2; exit 2; }

mkdir -p "$STATE/eindri-reports" "$STATE/eindri-questions" "$STATE/eindri-done"
kind="reported"
detail=""
if [ -f "$STATE/eindri-questions/$AGENT.md" ]; then
  # A question, not a report: the smith is blocked on the coordinator. Wake Brokk
  # with the need named, so the digest says ANSWER, not review.
  kind="QUESTION"
  detail="QUESTION at state/eindri-questions/$AGENT.md — answer with bin/eindri-send.sh $AGENT \"…\""
elif [ -f "$STATE/eindri-reports/$AGENT.md" ]; then
  detail="report filed at state/eindri-reports/$AGENT.md"
elif [ -n "$WORKTREE" ] && [ -f "$WORKTREE/REPORT.md" ]; then
  cp "$WORKTREE/REPORT.md" "$STATE/eindri-reports/$AGENT.md" 2>/dev/null || true
  detail="report filed from $WORKTREE/REPORT.md (state/eindri-reports/$AGENT.md)"
else
  detail="left working (herdr state flipped; read the pane: herdr agent read $AGENT)"
fi
printf 'eindri %s %s: %s\n' "$AGENT" "$kind" "$detail" >>"$STATE/.wake-queue"
printf '%s %s: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT" "$detail" >"$STATE/eindri-done/$AGENT.md"
if [ -x "$SCRIPT_DIR/ymir-say.sh" ]; then
  if [ "$kind" = "QUESTION" ]; then
    "$SCRIPT_DIR/ymir-say.sh" alarm "Eindri $AGENT asks — answer it" >/dev/null 2>&1 || true
  else
    "$SCRIPT_DIR/ymir-say.sh" note "Eindri $AGENT reported" >/dev/null 2>&1 || true
  fi
fi
printf 'eindri-acclaim[1]{agent,kind,detail}:\n  "%s","%s","%s"\n' "$AGENT" "$kind" "$detail"