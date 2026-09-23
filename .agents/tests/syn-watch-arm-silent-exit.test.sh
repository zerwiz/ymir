#!/usr/bin/env bash
# The watcher must never exit SILENTLY on an unchanged, unconsumed wake queue.
#
# A silent exit prints no signal:/stale:/check:/heartbeat: line, so the harness
# reads the close as "ended without an actionable reason", retries five times,
# and flaps — a single unacknowledged wake stranded supervision (2026-09-23).
# An unchanged queue must keep the watcher watching; a changed one signals once
# and exits (the flood brake).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM="$ROOT/bin/syn-watch-arm.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/state" "$TMP/machine"

# A non-empty queue with a matching recorded hash: already signalled once.
printf 'wake one\n' > "$TMP/state/.wake-queue"
md5sum < "$TMP/state/.wake-queue" | awk '{print $1}' > "$TMP/state/.wake-last-hash"

# A correct watcher stays alive until the timeout (exit 124); a flapping one
# exits 0 at once.
BROKK_STATE_OVERRIDE="$TMP/state" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  BROKK_WATCH_POLL_SECONDS=1 \
  timeout 5 bash "$ARM" --restart >"$TMP/out" 2>"$TMP/err"
rc=$?
if [ "$rc" = 124 ]; then
  ok "unchanged unconsumed queue keeps the watcher alive"
else
  bad "watcher exited $rc on an unchanged queue (silent exit)"
  sed 's/^/    /' "$TMP/out" "$TMP/err" 2>/dev/null || true
fi

# A changed queue raises exactly one signal and exits.
printf 'wake two\n' > "$TMP/state/.wake-queue"
BROKK_STATE_OVERRIDE="$TMP/state" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  BROKK_WATCH_POLL_SECONDS=1 \
  timeout 5 bash "$ARM" --restart >"$TMP/out2" 2>/dev/null
rc2=$?
if [ "$rc2" = 0 ] && grep -q '^signal: wake queue$' "$TMP/out2"; then
  ok "a changed queue signals once and exits"
else
  bad "changed queue: rc=$rc2 output=[$(cat "$TMP/out2")]"
fi

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
