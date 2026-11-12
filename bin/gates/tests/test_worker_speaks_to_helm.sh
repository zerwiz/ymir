#!/usr/bin/env bash
# test_worker_speaks_to_helm.sh — plan 272 faults 1 and 2.
# A worker runs with its own seat dir in BROKK_MACHINE_STATE_DIR and BROKK_STATE_OVERRIDE. What it says to the helm
# (the wake and the report) must land in the HOME's state, never in the seat's private dir.
# The doors are run from a copy with no well, in a temp home, so nothing real is touched.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

mkdir -p "$T/repo/bin/agents" "$T/repo/bin/vault" "$T/repo/RULES" "$T/repo/.pi" "$T/home/state" "$T/seat"
cp "$ROOT/bin/agents/eindri-acclaim.sh" "$ROOT/bin/agents/eindri-handoff.sh" "$ROOT/bin/agents/eindri-wake-lib.sh" "$T/repo/bin/agents/"
cp "$ROOT/bin/vault/hoard-lib.sh" "$T/repo/bin/vault/"

run() {  # run <script> <args…> as a worker seated in $T/seat
  env -i PATH="$PATH" HOME="$T" YMIR_HOME="$T/home" BROKK_ROOT_OVERRIDE="$T/repo" \
    BROKK_MACHINE_STATE_DIR="$T/seat" BROKK_STATE_OVERRIDE="$T/seat" \
    bash "$T/repo/bin/agents/$1" "${@:2}" 2>&1
}

printf 'failed: the test errand stopped\n' >"$T/home/state/w1.status"
run eindri-acclaim.sh w1 --terminal failed --line "the test errand stopped" >/dev/null
grep -q 'eindri w1 ' "$T/home/state/.wake-queue" 2>/dev/null && ok "the wake is in the helm's queue (home state)" || bad "the wake is in the helm's queue"
[ -e "$T/seat/.wake-queue" ] && bad "no wake in the seat's own queue" || ok "nothing is queued in the seat's private dir"
[ -s "$T/home/state/eindri-reports/w1.md" ] && ok "the report is on the helm's shelf" || bad "the report is on the helm's shelf"
[ -e "$T/seat/eindri-reports/w1.md" ] && bad "no report on the seat's shelf" || ok "no report is filed in the seat's private dir"

# the sweep reads the helm's shelves too
mkdir -p "$T/home/state/eindri-reports"; printf 'done: x\n' >"$T/home/state/eindri-reports/w2.md"
out="$(run eindri-handoff.sh status)"
printf '%s' "$out" | grep -q 'w2' && ok "the sweep finds a report on the helm's shelf" || bad "the sweep finds the helm's shelf: $out"

# a deliberate redirect (a test's own temp state) is still honoured
mkdir -p "$T/other"; printf 'failed: x\n' >"$T/other/w3.status"
env -i PATH="$PATH" HOME="$T" YMIR_HOME="$T/home" BROKK_ROOT_OVERRIDE="$T/repo" BROKK_STATE_OVERRIDE="$T/other" \
  bash "$T/repo/bin/agents/eindri-acclaim.sh" w3 --terminal failed --line "x" >/dev/null 2>&1
grep -q 'eindri w3 ' "$T/other/.wake-queue" 2>/dev/null && ok "an explicit state override that is not the seat's is honoured" || bad "explicit override honoured"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
