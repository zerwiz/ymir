#!/usr/bin/env bash
# claude-stop-arm.sh — Claude Code's Stop-hook arm: ONE client per session, only for the helm,
# and a wake that arrives with its instruction (plan 239 P4, proven 2026-11-10).
#
# Registered in .claude/settings.json as a Stop command with "asyncRewake": true. Claude fires it in
# the background on EVERY Stop and never de-duplicates, so before this wrapper one session carried
# seven arm clients at once — one of them still attached to the previous arm service — and a single
# wake could rouse the session several times. Three rules, in order:
#
#   1. THE HELM ONLY. A session that does not hold the Gleipnir lock never arms (exit 0): a read-only
#      guest must not wake for the primary's work. (Checked with bin/records/ymir-state.sh.)
#   2. SINGLE-FLIGHT. An exclusive flock on <state>/.claude-arm.<session>.lock is held for the whole
#      life of the client; a second firing finds it taken and exits 0. The lock dies with the client,
#      so the next Stop after a wake seats exactly one successor.
#   3. THE BANNER CARRIES THE ORDER. An actionable line (signal:/stale:/check:/heartbeat:) is printed
#      to stderr with the same instruction Pi's extension gives — drain first, answer Rödd in her
#      room — and exits 2, which wakes Claude even while idle.
#
# Inert outside a checkout with bin/pi/syn-watch-arm.sh. Exit: 0 inert/healthy · 2 wake.
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cat >/dev/null 2>&1 || true            # drain the hook payload; we never block on it
[ -x "$ROOT/bin/pi/syn-watch-arm.sh" ] || exit 0

session="$(bash "$ROOT/bin/records/ymir-state.sh" lock session-pid --shell-pid $$ 2>/dev/null | tr -d '[:space:]')"
bash "$ROOT/bin/records/ymir-state.sh" lock owned --shell-pid $$ >/dev/null 2>&1 || exit 0

STATE=""
[ -r "$ROOT/bin/vault/hoard-lib.sh" ] && . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && command -v hoard_state_dir >/dev/null 2>&1 && hoard_state_dir STATE 2>/dev/null
STATE="${STATE:-$ROOT/state}"
mkdir -p "$STATE" 2>/dev/null || true
exec 9>"$STATE/.claude-arm.${session:-unknown}.lock" || exit 0
flock -n 9 || exit 0

# plan 257 H6: run the PIN's client, never this checkout's — the code that decides what a
# wake means is always the pinned runtime's, whatever branch this tree stands on.
client=""
[ -r "$ROOT/bin/pi/arm-pin-lib.sh" ] && . "$ROOT/bin/pi/arm-pin-lib.sh" && arm_pin_client client
out="$("${client:-$ROOT/bin/pi/syn-watch-arm.sh}" --restart 9>&-)"; rc=$?
case "$out" in
  *signal:*|*stale:*|*check:*|*heartbeat:*)
    {
      printf 'BROKK WATCHER WAKE:\n%s\n\n' "$out"
      printf 'Run bin/time/saga-wake-drain.sh first and handle every queued wake; acknowledge with `saga-wake-drain.sh ack`.\n'
      printf 'A wake from Rödd is answered in her room: bin/voice/rodd-room.sh reply "<text>".\n'
      printf 'Watcher continuity is hook-owned: do not arm another cycle yourself.\n'
    } >&2
    exit 2 ;;
esac
exit "$rc"
