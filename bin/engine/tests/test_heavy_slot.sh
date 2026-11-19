#!/usr/bin/env bash
# test_heavy_slot.sh — plan 002 §6.1: the machine's heavy lock is real.
#
# WHY. `updating.md`'s first law was "one heavy job at a time — `bin/heavy-slot.sh take` before a
# build", and the command did not exist anywhere in the tree. On 2026-11-17 that cost the heart:
# a gate suite, a release build and seven errands proceeded together on 11 GB of RAM with 3.0 of
# 4.0 GB of swap already in use, and the kernel fired at 07:20:59.
#
# WHAT THIS PROVES, each one a command and its printed output:
#   1. a free slot says free, and `run` runs the command and gives the slot back
#   2. two heavy jobs started at once: the SECOND prints the holder and waits, and only then runs
#   3. `--no-wait` refuses (exit 3) and names the holder instead of running beside it
#   4. a holder that is gone is REAPED — a stale lock never blocks the machine forever
#   5. a lock whose pid was REUSED by another process is stale too (pid + start time, not pid)
#   6. a holder killed by a signal releases the slot on the way out
#   7. a heavy job inside a heavy job NESTS instead of deadlocking on its own lock
#   8. status --json names the holder for a machine reader
#
# Everything runs against a temporary state directory: the real machine-wide lock is never taken,
# nothing is built, and nothing outside the temp dir is written.
set -uo pipefail
SLOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)/bin/heavy-slot.sh"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# The lock lives under XDG_STATE_HOME by default; fence it so the real machine lock is untouched.
export XDG_STATE_HOME="$T/state"
unset YMIR_HEAVY_SLOT YMIR_HEAVY_SLOT_HELD YMIR_HEAVY_SLOT_PID 2>/dev/null || true
# ONE LANE for the single-lane proofs below: the machine's own lane count is read from the home's
# registry, and this test must prove the queueing behaviour whatever this box carries.
export YMIR_HEAVY_SLOTS=1
LOCK="$XDG_STATE_HOME/ymir/heavy-slot.lock"
ORDER="$T/order"; : >"$ORDER"

[ -x "$SLOT" ] || { echo "  FAIL the door does not exist at $SLOT"; exit 1; }

# wait_lock_with <text> — poll the lock file until it carries that text (5s), then true
wait_lock_with() {
  local i=0
  while [ "$i" -lt 50 ]; do
    [ -r "$LOCK" ] && grep -q -- "$1" "$LOCK" 2>/dev/null && return 0
    sleep 0.1; i=$((i + 1))
  done
  return 1
}

# ── 1. a free slot, and a run that gives it back ──────────────────────────────
free_says_free()     { "$SLOT" status | grep -q '"free"'; }
runs_and_releases()  { "$SLOT" run --name solo -- sh -c "echo solo >>'$ORDER'" >/dev/null 2>&1; }
locked_after_run()   { [ -e "$LOCK" ] && return 1; return 0; }
t "a free slot says free"                                  free_says_free
t "run runs the command"                                   runs_and_releases
t "the slot is free again after the run (no lock left)"    locked_after_run
grep -qx solo "$ORDER" || { echo "  FAIL the command did not actually run"; fail=$((fail+1)); }

# ── 2. two heavy jobs at once: the second waits and says whose job it waits for ──
: >"$ORDER"
"$SLOT" run --name job-a -- sh -c "sleep 3; echo a >>'$ORDER'" >"$T/a.out" 2>&1 &
A=$!
if wait_lock_with 'name=job-a'; then
  "$SLOT" run --name job-b -- sh -c "echo b >>'$ORDER'" >"$T/b.out" 2>&1 &
  B=$!
  sleep 1
  second_names_holder() { grep -q 'SLOT,waiting' "$T/b.out" && grep -q '"job-a"' "$T/b.out"; }
  second_waited()       { ! grep -qx b "$ORDER" 2>/dev/null; }
  t "the second job prints the holder it waits for" second_names_holder
  t "the second job did NOT start beside the first" second_waited
  wait "$A" "$B" 2>/dev/null
  ordered() { [ "$(tr '\n' ' ' <"$ORDER" | sed 's/ *$//')" = "a b" ]; }
  t "the second job ran, after the first finished" ordered
  t "the slot is free after both" locked_after_run
else
  echo "  FAIL the first job never took the slot"
  fail=$((fail + 2))
  kill "$A" 2>/dev/null
fi

# ── 3. --no-wait refuses and names the holder ────────────────────────────────
"$SLOT" run --name holding -- sleep 3 >/dev/null 2>&1 &
C=$!
if wait_lock_with 'name=holding'; then
  "$SLOT" run --no-wait --name refuser -- sh -c "echo SHOULD-NOT-RUN >>'$ORDER'" >"$T/c.out" 2>&1
  rc=$?
  refuses()      { [ "$rc" -eq 3 ]; }
  refuses_names() { grep -q 'SLOT,refused' "$T/c.out" && grep -q '"holding"' "$T/c.out"; }
  refuses_ran_nothing() { ! grep -q SHOULD-NOT-RUN "$ORDER"; }
  t "--no-wait refuses with exit 3"                refuses
  t "the refusal names the holder it would wait for" refuses_names
  t "the refused job ran nothing"                  refuses_ran_nothing
  # ── 8. status --json names the holder for a machine reader ─────────────────
  # (written to a file first: a pipe to `grep -q` closes early and would report the SIGPIPE,
  #  not the verdict)
  json_says_held() { "$SLOT" status --json >"$T/j.out" 2>/dev/null; grep -q '"state":"held"' "$T/j.out"; }
  t "status --json reports the slot held"          json_says_held
  wait "$C" 2>/dev/null
else
  echo "  FAIL could not take the slot for the refusal check"
  fail=$((fail + 4))
fi

# ── 4. a holder that is gone is reaped ───────────────────────────────────────
mkdir -p "$(dirname "$LOCK")"
dead_pid=4194303                       # above the default pid_max: no such process
printf 'pid=%s\nstarted=2026-11-17T00:00:00Z\nstarttime=1\nhost=probe\nname=dead-job\ncmd=sleep 999\n' \
  "$dead_pid" >"$LOCK"
stale_reaped()  { "$SLOT" status >"$T/d.out" 2>&1 && grep -q '"free"' "$T/d.out" && [ ! -e "$LOCK" ]; }
t "a lock whose holder is gone is reaped"                  stale_reaped

# ── 5. pid reuse: a live pid with a different start time is stale ────────────
printf 'pid=%s\nstarted=2026-11-17T00:00:00Z\nstarttime=1\nhost=probe\nname=reused-pid\ncmd=sleep 999\n' \
  "$$" >"$LOCK"
reused_reaped() { "$SLOT" status >"$T/e.out" 2>&1 && grep -q '"free"' "$T/e.out" && [ ! -e "$LOCK" ]; }
t "a lock whose pid was reused is reaped (start time, not pid)"  reused_reaped

# ── 6. a signal releases the slot ────────────────────────────────────────────
# `exec` matters: the job replaces its shell, so the runner's TERM reaches the process itself and no
# orphan is left behind. (The first version killed the leftovers with `pkill`, which the platform gate
# refuses — a blunt kill by name is not portable, and it was reaping a process we could have avoided.)
"$SLOT" run --name signal-job -- sh -c 'exec sleep 30' >/dev/null 2>&1 &
S=$!
if wait_lock_with 'name=signal-job'; then
  kill -TERM "$S" 2>/dev/null
  wait "$S" 2>/dev/null
  signal_released() { [ ! -e "$LOCK" ] && "$SLOT" status >/dev/null 2>&1; }
  t "a holder killed by a signal gives the slot back" signal_released
else
  echo "  FAIL could not take the slot for the signal check"
  fail=$((fail + 1))
  kill "$S" 2>/dev/null
fi

# ── 7. a heavy job inside a heavy job nests ──────────────────────────────────
nested() {
  "$SLOT" run --name outer -- "$SLOT" run --name inner -- sh -c "echo nested-ran >>'$ORDER'" \
    >"$T/n.out" 2>&1 || return 1
  grep -q 'SLOT,nested,inner' "$T/n.out" && grep -q nested-ran "$ORDER" && [ ! -e "$LOCK" ]
}
t "a heavy job inside a heavy job nests, and the slot is free after" nested

# ── 9. the lane count is the machine's, and the lanes really are counted ─────
# The Allfather, 2026-11-18: "the server can handle more builders". Two lanes must let two heavy
# jobs run BESIDE each other, and a third must wait — and a lane must be released on its own.
lanes_are_read()      { YMIR_HEAVY_SLOTS=2 "$SLOT" lanes | grep -q '"2","env YMIR_HEAVY_SLOTS"'; }
t "the lane count is read, and says where it came from"      lanes_are_read
: >"$ORDER"
LANE2="${LOCK%.lock}.2.lock"
two_lanes_run_together() {
  YMIR_HEAVY_SLOTS=2 "$SLOT" run --name lane-a -- sh -c "sleep 3; echo a >>'$ORDER'" >"$T/la.out" 2>&1 &
  LA=$!
  if ! wait_lock_with 'name=lane-a'; then kill "$LA" 2>/dev/null; return 1; fi
  YMIR_HEAVY_SLOTS=2 "$SLOT" run --name lane-b -- sh -c "echo b >>'$ORDER'" >"$T/lb.out" 2>&1 &
  LB=$!
  sleep 1
  # lane-b must have RUN BESIDE lane-a: it is in the order while a is still asleep, and it
  # never printed that it was waiting for a lane.
  [ "$(tr '\n' ' ' <"$ORDER" | sed 's/ *$//')" = "b" ] || { echo "    order was: $(cat "$ORDER" | tr '\n' ' ')"; }
  grep -q 'SLOT,waiting' "$T/lb.out" && { echo "    lane-b waited: $(cat "$T/lb.out")"; return 1; }
  wait "$LA" "$LB" 2>/dev/null
  [ "$(tr '\n' ' ' <"$ORDER" | sed 's/ *$//')" = "b a" ]
}
t "two lanes run two heavy jobs beside each other"           two_lanes_run_together
two_lanes_second_file() { [ ! -e "$LOCK" ] && [ ! -e "$LANE2" ]; }
t "both lanes are given back (no lock file left)"            two_lanes_second_file
third_job_waits() {
  YMIR_HEAVY_SLOTS=2 "$SLOT" run --name one -- sleep 4 >/dev/null 2>&1 &
  P1=$!; YMIR_HEAVY_SLOTS=2 "$SLOT" run --name two -- sleep 4 >/dev/null 2>&1 &
  P2=$!
  # wait until BOTH lane files are held, then ask a third job to stand in line and give up
  local i=0
  while [ "$i" -lt 50 ]; do
    [ -r "$LOCK" ] && [ -r "$LANE2" ] && break
    sleep 0.1; i=$((i + 1))
  done
  YMIR_HEAVY_SLOTS=2 "$SLOT" run --no-wait --name third -- sh -c "echo SHOULD-NOT-RUN >>'$ORDER'" \
    >"$T/l3.out" 2>&1
  local rc=$?
  wait "$P1" "$P2" 2>/dev/null
  [ "$rc" -eq 3 ] && grep -q '"one"' "$T/l3.out" && grep -q 'every lane is held' "$T/l3.out" \
    && ! grep -q SHOULD-NOT-RUN "$ORDER"
}
t "with both lanes held, a third job is refused and names the holders"  third_job_waits
status_counts_lanes() { YMIR_HEAVY_SLOTS=2 "$SLOT" status --json >"$T/ls.out" 2>/dev/null; grep -q '"lanes":2' "$T/ls.out"; }
t "status --json reports the lane count of the machine"       status_counts_lanes

printf 'heavy-slot: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
