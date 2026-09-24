#!/usr/bin/env bash
# eindri-acclaim-silent.sh — action half of the Eindri silence bridge.
#
# Runs once when the silence when-adapter fires (a worker went SILENT: no
# status append inside the window). Wakes Brokk with the worker's id, elapsed
# time, and last line, idempotent via state/eindri-silent/<agent> markers: a
# wake is written only when the marker is absent or the status file has grown
# since it (the worker was active again, then stalled again). A continuously
# silent worker is woken once, not every poll.
#
# Usage: bin/eindri-acclaim-silent.sh <agent>
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
AGENT="${1:-}"
[ -n "$AGENT" ] || { echo "usage: eindri-acclaim-silent.sh <agent>" >&2; exit 2; }

mkdir -p "$STATE/eindri-silent"
STATUS="$STATE/$AGENT.status"
MARKER="$STATE/eindri-silent/$AGENT.size"

size_now=0
if [ -f "$STATUS" ]; then
  size_now=$(stat -c '%s' "$STATUS" 2>/dev/null || stat -f '%z' "$STATUS" 2>/dev/null || echo 0)
fi
size_marker=0
[ -f "$MARKER" ] && size_marker=$(cat "$MARKER" 2>/dev/null || echo 0)
case "$size_marker" in ''|*[!0-9]*) size_marker=0 ;; esac
# already reported the CURRENT silence epoch: do not ring again every poll
if [ "$size_marker" -ge "$size_now" ] && [ "$size_marker" -gt 0 ]; then
  printf 'eindri-acclaim-silent[1]{agent,state}:\n  "%s","already reported (silence epoch unchanged) — no re-wake"\n' "$AGENT"
  exit 0
fi
printf '%s\n' "$size_now" > "$MARKER"

launched=$(grep '^launched=' "$STATE/$AGENT.meta" 2>/dev/null | tail -1 | cut -d= -f2-)
now=$(date +%s)
elapsed="unknown"
case "$launched" in ''|*[!0-9]*) ;; *) elapsed="$((now - launched))s" ;; esac
last_line=$(tail -n1 "$STATUS" 2>/dev/null || echo "(no status lines)")

printf 'eindri %s SILENT: no status append for a while (elapsed %s) — last line: %s\n' \
  "$AGENT" "$elapsed" "$last_line" >>"$STATE/.wake-queue"
printf '%s\n%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "elapsed=$elapsed last_line=$last_line" >"$STATE/eindri-silent/$AGENT.md"
if [ -x "$SCRIPT_DIR/ymir-say.sh" ]; then
  "$SCRIPT_DIR/ymir-say.sh" note "Eindri $AGENT may be silent — check it" >/dev/null 2>&1 || true
fi
printf 'eindri-acclaim-silent[1]{agent,elapsed,last_line}:\n  "%s","%s","%s"\n' "$AGENT" "$elapsed" "$last_line"