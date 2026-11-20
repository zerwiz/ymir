#!/usr/bin/env bash
# test_eindri_stall.sh — the arm's stall test, driven by a frozen pane and a simulated clock.
#
# The fault (2026-11-20, the Allfather's word that night — *"this should rodd take care of
# and the arm"*): two errands sat 8h45m and 1h50m on one command while `eindri-liveness.sh`
# judged both ALIVE, because the AGENT still stood in the pane. Nothing woke the helm.
#
# Every case below is the behaviour the runbook asks for, and nothing real is touched:
# a throwaway state dir, a directory of fake panes (plain files the test rewrites or
# freezes), a simulated clock, and the send and notify doors replaced by files that
# record what would have been typed and sent. No herdr, no tmux, no live pane.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/agents/eindri-stall.sh"
[ -x "$DOOR" ] || { printf 'FAIL no %s\n' "$DOOR"; exit 1; }

ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$2"; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export YMIR_STATE_DIR="$T/state"
export YMIR_STALL_PANE_DIR="$T/panes"
export YMIR_STALL_SEND_CMD="$T/sends"
export YMIR_STALL_NOTIFY_CMD="$T/notes"
mkdir -p "$YMIR_STATE_DIR" "$YMIR_STALL_PANE_DIR"

# A seated, working errand: the meta the spawn wrote, the status line the worker appended.
seat() {  # <id> [status-line]
  printf 'id=%s\nkind=ship\nbackend=herdr\nwindow=w9:p%s\nworktree=%s\n' "$1" "${2:-1}" "$T" >"$YMIR_STATE_DIR/$1.meta"
  printf '%s\n' "${3:-working: forging something}" >"$YMIR_STATE_DIR/$1.status"
}
pane() { printf '%s\n' "$2" >"$YMIR_STALL_PANE_DIR/$1.log"; }
sweep() { YMIR_STALL_CLOCK="$1" bash "$DOOR" sweep "${@:2}" >/dev/null 2>&1; echo $?; }
# `grep -c` prints 0 AND exits 1 on no match; `|| echo 0` would then count twice.
count() { local n=0; [ -f "$1" ] && n="$(grep -c . "$1" 2>/dev/null)"; printf '%s' "${n:-0}"; }
wakes() { local n=0; [ -f "$YMIR_STATE_DIR/.wake-queue" ] && n="$(grep -c "stall: errand $1 " "$YMIR_STATE_DIR/.wake-queue" 2>/dev/null)"; printf '%s' "${n:-0}"; }

# ── 1. a pane that is moving wakes nobody ─────────────────────────────────────────────
seat moving
pane moving "reading the tree
editing bin/agents/example.sh"
t0=1700000000
rc="$(sweep "$t0" moving)"
pane moving "reading the tree
editing bin/agents/example.sh
running the test"
rc="$(sweep $((t0 + 600)) moving)"
[ "$rc" = 0 ] && good "a moving pane is a clean sweep (rc 0)" || bad "a moving pane returned rc $rc"
[ "$(count "$YMIR_STALL_SEND_CMD")" = 0 ] && good "a moving pane is never steered" || bad "a moving pane was steered"
[ "$(wakes moving)" = 0 ] && good "a moving pane wakes nobody" || bad "a moving pane woke the helm"

# ── 2. frozen for 20 minutes: ONE wake and ONE steer ─────────────────────────────────
seat frozen
pane frozen "bash test_dispatch.py
waiting on input"
sweep "$t0" frozen >/dev/null
rc="$(sweep $((t0 + 300)) frozen)"
[ "$rc" = 0 ] && good "quiet inside the window is not stuck (rc 0)" || bad "quiet inside the window returned rc $rc"
[ "$(count "$YMIR_STALL_SEND_CMD")" = 0 ] && good "no steer before the window is spent" || bad "steered before the window was spent"
rc="$(sweep $((t0 + 1200)) frozen)"
[ "$rc" = 3 ] && good "frozen 20 minutes is STUCK (rc 3)" || bad "frozen 20 minutes returned rc $rc"
[ "$(wakes frozen)" = 1 ] && good "one durable wake for the helm" || bad "expected 1 wake, got $(wakes frozen)"
grep -q "pane w9:p1" "$YMIR_STATE_DIR/.wake-queue" && good "the wake names the pane" || bad "the wake does not name the pane"
grep -q "waiting on input" "$YMIR_STATE_DIR/.wake-queue" && good "the wake carries the pane's last lines" || bad "the wake carries no lines"
[ "$(count "$YMIR_STALL_SEND_CMD")" = 1 ] && good "one line typed into the worker" || bad "expected 1 steer, got $(count "$YMIR_STALL_SEND_CMD")"
grep -q "STALL CHECK from the arm" "$YMIR_STALL_SEND_CMD" && good "the steer says what it is" || bad "the steer has the wrong words"

# ── 3. a second sweep in the SAME stall adds nothing ─────────────────────────────────
sweep $((t0 + 1260)) frozen >/dev/null
[ "$(wakes frozen)" = 1 ] && good "a second sweep does not wake twice" || bad "the wake repeated"
[ "$(count "$YMIR_STALL_SEND_CMD")" = 1 ] && good "a second sweep does not steer twice" || bad "the steer repeated"
[ "$(count "$YMIR_STALL_NOTIFY_CMD")" = 0 ] && good "ten minutes have not passed since the wake" || bad "the operator was told early"

# ── 4. ten minutes after the wake, and still unmoved: ONE operator message ───────────
rc="$(sweep $((t0 + 1800)) frozen)"
[ "$(count "$YMIR_STALL_NOTIFY_CMD")" = 1 ] && good "the operator is told once, ten minutes after the wake" || bad "expected 1 message, got $(count "$YMIR_STALL_NOTIFY_CMD")"
grep -q "frozen has not moved" "$YMIR_STALL_NOTIFY_CMD" && good "the message names the errand and the wait" || bad "the message is vague"
grep -q "waiting on input" "$YMIR_STALL_NOTIFY_CMD" && good "the message carries the last line" || bad "the message carries no last line"
sweep $((t0 + 2400)) frozen >/dev/null
[ "$(count "$YMIR_STALL_NOTIFY_CMD")" = 1 ] && good "the operator is never told twice about one stall" || bad "the operator was told again"

# ── 5. the pane moves again: the stall is cleared, and the next one fires afresh ─────
pane frozen "bash test_dispatch.py
Test finished: 41 passed"
rc="$(sweep $((t0 + 2460)) frozen)"
[ "$rc" = 0 ] && good "a pane that moves again is not stuck" || bad "a moved pane returned rc $rc"
pane frozen "bash test_dispatch.py
still going"
sweep $((t0 + 2500)) frozen >/dev/null
sweep $((t0 + 3700)) frozen >/dev/null
[ "$(wakes frozen)" = 2 ] && good "a NEW stall wakes again (one per stall, keyed by its start)" || bad "expected 2 wakes, got $(wakes frozen)"

# ── 6. one command past its own limit is stuck at once, with no quiet window ─────────
seat longrun
pane longrun "ssh host-a 'bash deploy.sh'
  Elapsed 42m 07s"
rc="$(sweep $((t0 + 4000)) longrun)"
[ "$rc" = 3 ] && good "a command past 30 minutes is STUCK on the first look" || bad "a long command returned rc $rc"
grep -q "past its 30 min limit" "$YMIR_STATE_DIR/.wake-queue" && good "the wake says which limit was passed" || bad "the wake does not name the limit"

# ── 7. a spinner is not movement ─────────────────────────────────────────────────────
seat spinner
pane spinner "⠋ Running the gate suite"
sweep $((t0 + 5000)) spinner >/dev/null
pane spinner "⠙ Running the gate suite"
sweep $((t0 + 5300)) spinner >/dev/null
pane spinner "⠹ Running the gate suite"
rc="$(sweep $((t0 + 6200)) spinner)"
[ "$rc" = 3 ] && good "a redrawing spinner does not count as movement" || bad "the spinner fooled the sweep (rc $rc)"

# ── 8. the footer's token counter IS movement ────────────────────────────────────────
seat working_turn
pane working_turn "writing the fix
↑400k ↓61k \$0.10"
sweep $((t0 + 7000)) working_turn >/dev/null
pane working_turn "writing the fix
↑412k ↓62k \$0.11"
rc="$(sweep $((t0 + 8300)) working_turn)"
[ "$rc" = 0 ] && good "an advancing token counter is movement, even with the same last line" || bad "the token counter was ignored (rc $rc)"

# ── 9. a closed claim is not a claim of movement ─────────────────────────────────────
seat closed
pane closed "bash test.py"
sweep $((t0 + 9000)) closed >/dev/null
printf 'done: shipped\n' >"$YMIR_STATE_DIR/closed.status"
before="$(wakes closed)"
rc="$(sweep $((t0 + 11000)) closed)"
[ "$before" = 0 ] && [ "$rc" = 0 ] && good "an errand that reported done is never called stuck" || bad "a done errand was judged (rc $rc)"

# ── 10. a pane that cannot be read is UNKNOWN, never a false alarm ───────────────────
seat unreadable
rm -f "$YMIR_STALL_PANE_DIR/unreadable.log"
rc="$(sweep $((t0 + 12000)) unreadable)"
out="$(YMIR_STALL_CLOCK=$((t0 + 12001)) bash "$DOOR" check unreadable 2>&1)"
[ "$rc" = 0 ] && good "an unreadable pane is not called stuck" || bad "an unreadable pane returned rc $rc"
printf '%s' "$out" | grep -q UNKNOWN && good "it is printed as UNKNOWN with its reason" || bad "the unreadable pane was not named: $out"

# ── 11. check changes nothing ────────────────────────────────────────────────────────
: >"$YMIR_STALL_SEND_CMD"; : >"$YMIR_STALL_NOTIFY_CMD"
YMIR_STALL_CLOCK=$((t0 + 13000)) bash "$DOOR" check frozen >/dev/null 2>&1
[ "$(count "$YMIR_STALL_SEND_CMD")" = 0 ] && [ "$(count "$YMIR_STALL_NOTIFY_CMD")" = 0 ] \
  && good "check judges and writes nothing" || bad "check typed into a pane or messaged the operator"

printf '\n%d ok, %d failed\n' "$ok" "$fail"
[ "$fail" -eq 0 ]
