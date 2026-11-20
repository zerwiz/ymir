#!/usr/bin/env bash
# The arm must never exit SILENTLY on an unchanged, unconsumed wake queue — and
# since plan 58 Phase 2 it must never retire with its session either.
#
# A silent exit prints no signal:/stale:/check:/heartbeat: line, so the harness
# reads the close as "ended without an actionable reason", retries five times,
# and flaps — a single unacknowledged wake stranded supervision (2026-09-23).
# An unchanged queue must keep the watch watching; a changed one signals once.
#
# The watch loop is now the SERVICE (bin/syn-watch.sh run) and bin/syn-watch-arm.sh
# is its thin client. So this asserts BOTH halves: the loop's flood brake, and
# the client relaying what the service raised — including a line raised while no
# client was attached, and a service the client had to re-seat itself.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARM="$ROOT/bin/syn-watch-arm.sh"
WATCH="$ROOT/bin/syn-watch.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
export BROKK_STATE_OVERRIDE="$TMP/state"
export BROKK_MACHINE_STATE_DIR="$TMP/machine"
export BROKK_WATCH_POLL_SECONDS=1
mkdir -p "$BROKK_STATE_OVERRIDE" "$BROKK_MACHINE_STATE_DIR"
cleanup() { "$WATCH" stop >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT

# ── the service seats with NO session (idle-not-dead) ───────────────────────
"$WATCH" start >/dev/null 2>&1
if "$WATCH" status >/dev/null 2>&1; then
  ok "the arm seats and reports healthy with no session seated"
else
  bad "the arm did not seat: $("$WATCH" status --detail 2>&1)"
fi

# ── the flood brake: an unchanged, unconsumed queue keeps the watch alive ───
printf 'wake one\n' > "$BROKK_STATE_OVERRIDE/.wake-queue"
sleep 3   # let the service raise it and record the hash
timeout 4 bash "$ARM" --restart >"$TMP/out1" 2>"$TMP/err1"
rc=$?
grep -q '^signal: wake queue$' "$TMP/out1" && ok "a changed queue signals once" \
  || bad "changed queue: rc=$rc output=[$(cat "$TMP/out1")]"
# The queue is unchanged and unconsumed now: the next client must WAIT.
timeout 4 bash "$ARM" --restart >"$TMP/out2" 2>"$TMP/err2"
rc2=$?
if [ "$rc2" = 124 ]; then
  ok "an unchanged unconsumed queue keeps the client watching"
else
  bad "client exited $rc2 on an unchanged queue (silent exit)"
  sed 's/^/    /' "$TMP/out2" "$TMP/err2" 2>/dev/null || true
fi

# ── the thin client: attaches to the service and relays what it raised ──────
case "$(cat "$TMP/out2" 2>/dev/null)" in
  *'watcher: started'*'watcher: attached'*) ok "the client attaches to the standing service" ;;
  *) bad "the client did not announce an attach: [$(cat "$TMP/out2" 2>/dev/null)]" ;;
esac

# A line raised with NO client attached must reach the NEXT client (the durable
# delivery slot), so a wake is never lost between sessions.
printf 'wake two\n' > "$BROKK_STATE_OVERRIDE/.wake-queue"
sleep 3
timeout 6 bash "$ARM" --restart >"$TMP/out3" 2>/dev/null
if grep -q '^signal: wake queue$' "$TMP/out3"; then
  ok "a line raised with no client attached is delivered to the next client"
else
  bad "the pending line was not delivered: [$(cat "$TMP/out3")]"
fi

# ── the service outlives its own death: the client re-seats it ──────────────
dead="$(sed -n 's/^pid=\([^ ]*\).*/\1/p' "$BROKK_STATE_OVERRIDE/.arm.lease")"
kill -9 "$dead" 2>/dev/null
sleep 1
printf 'wake three\n' > "$BROKK_STATE_OVERRIDE/.wake-queue"
BROKK_WATCH_DAEMON_GRACE_SECONDS=3 timeout 20 bash "$ARM" --restart >"$TMP/out4" 2>"$TMP/err4"
live="$(sed -n 's/^pid=\([^ ]*\).*/\1/p' "$BROKK_STATE_OVERRIDE/.arm.lease")"
if [ -n "$live" ] && [ "$live" != "$dead" ] && kill -0 "$live" 2>/dev/null; then
  ok "a killed arm is re-seated (pid $dead -> $live)"
else
  bad "the arm was not re-seated: dead=$dead live=$live err=[$(cat "$TMP/err4" 2>/dev/null)]"
fi
grep -q '^signal: wake queue$' "$TMP/out4" && ok "the re-seated arm delivers the waiting wake" \
  || bad "the re-seated arm delivered nothing: [$(cat "$TMP/out4")]"

# ── the gap is loud, not silent ─────────────────────────────────────────────
printf 'wake four\n' > "$BROKK_STATE_OVERRIDE/.wake-queue"
"$WATCH" stop >/dev/null 2>&1
if "$WATCH" status >/dev/null 2>&1; then
  bad "status reported healthy with no live arm"
else
  ok "status exits non-zero when the arm is gone"
fi

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
