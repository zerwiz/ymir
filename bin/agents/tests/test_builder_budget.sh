#!/usr/bin/env bash
# test_builder_budget.sh — the machine says how many builders it carries, and the door tells the truth.
#
# WHY (the Allfather, 2026-11-18): "we can only have one builder at the time. here. … the server can
# handle more builders". The budget is a NUMBER OWNED BY THE MACHINE (`hosts.<host>.builders` in the
# home's fleet registry), so the proofs are: it is read by hostname, an unreadable registry is
# UNKNOWN and never a green zero, and a machine at its budget says so and refuses.
#
# Every proof runs against a temporary registry and a fixture agent list: the real home is never
# read, no agent is spawned, and nothing outside the temp dir is written.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/agents/builder-budget.sh"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
[ -x "$DOOR" ] || { echo "  FAIL the door does not exist at $DOOR"; exit 1; }
HOST="$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')"
unset YMIR_BUILDER_BUDGET 2>/dev/null || true

# a registry holding THIS host's row, and a door that reports N agents in worktrees
registry_with() {  # <builders>
  mkdir -p "$T/home/hodd/data"
  printf '{"hosts":{"%s":{"roles":["heart"],"builders":%s}}}\n' "$HOST" "$1" >"$T/home/hodd/data/fleet.json"
}
door_with() {  # <n builders in worktrees> <n agents elsewhere>
  cat >"$T/door.py" <<PY
#!/usr/bin/env python3
import sys
if "--tsv" not in sys.argv: sys.exit(1)
for i in range($1):
    print("w9:p%d\tworking\tpi\tw9:t%d\tw9\tfalse\t/home/x/ymir/.yggdrasil/errand-%d" % (i, i, i))
for i in range($2):
    print("w1:p%d\tidle\tpi\tw1:t%d\tw1\tfalse\t/home/x/ymir" % (i, i))
PY
  chmod +x "$T/door.py"
  export YMIR_AGENT_LIST_DOOR="$T/door.py"
}
door_silent() { printf '#!/bin/sh\nexit 1\n' >"$T/door.py"; chmod +x "$T/door.py"; export YMIR_AGENT_LIST_DOOR="$T/door.py"; }

export YMIR_HOME="$T/home"
export YMIR_FLEET_REGISTRY="$T/home/hodd/data/fleet.json"

# ── 1. the number is the machine's own row, read by hostname ─────────────────
registry_with 4; door_with 0 1
reads_own_row()    { "$DOOR" read >"$T/r1.out" 2>&1 && grep -q '"4"' "$T/r1.out" && grep -q "$HOST" "$T/r1.out"; }
t "the budget is read from this host's own row"                 reads_own_row
env_overrides()    { YMIR_BUILDER_BUDGET=7 "$DOOR" read | grep -q '"7"'; }
t "an explicit YMIR_BUILDER_BUDGET overrides the row"           env_overrides

# ── 2. an unreadable registry is UNKNOWN, never a green zero ────────────────
rm -f "$T/home/hodd/data/fleet.json"
unknown_is_not_zero() {
  "$DOOR" read >"$T/r2.out" 2>&1
  local rc=$?
  [ "$rc" -eq 4 ] && grep -q 'unknown' "$T/r2.out" && ! grep -q '"0"' "$T/r2.out"
}
t "no registry row → exit 4 and 'unknown', never 0"             unknown_is_not_zero
a_door_that_cannot_say() {
  registry_with 4; door_silent
  "$DOOR" status >"$T/r3.out" 2>&1
  local rc=$?
  [ "$rc" -eq 4 ] && grep -q 'herdr cannot say' "$T/r3.out"
}
t "a seat door that cannot answer → 'unknown', exit 4"          a_door_that_cannot_say

# ── 3. the count is builders in WORKTREES; the helm in the main hall is not one ──
registry_with 4; door_with 2 3
counts_worktrees() {
  "$DOOR" status >"$T/s1.out" 2>&1
  local rc=$?
  [ "$rc" -eq 0 ] && grep -q '"2"' "$T/s1.out" && grep -q 'room,2' "$T/s1.out"
}
t "two builders in worktrees, three agents elsewhere → 2, room 2"  counts_worktrees

# ── 4. a machine at its budget says so, and refuses ─────────────────────────
door_with 4 0
at_budget_refuses() {
  "$DOOR" status >"$T/s2.out" 2>&1
  local rc=$?
  [ "$rc" -eq 3 ] && grep -q 'is full' "$T/s2.out"
}
t "at the budget: exit 3 and the machine is full"                at_budget_refuses
check_at_budget()  { "$DOOR" check >/dev/null 2>&1; [ $? -eq 3 ]; }
t "check refuses (exit 3) when the budget is full"              check_at_budget

# ── 5. over the budget is reported too, never clamped to "full" only ────────
door_with 5 0
over_budget_reports() { "$DOOR" status >"$T/s3.out" 2>&1; grep -q 'room,-1' "$T/s3.out"; }
t "one over the budget is reported as room,-1"                  over_budget_reports

# ── 6. a machine reader gets the numbers, not prose ─────────────────────────
registry_with 4; door_with 1 0
json_shape() { "$DOOR" status --json >"$T/j.out" 2>/dev/null; grep -q '"budget":4' "$T/j.out" && grep -q '"builders":1' "$T/j.out" && grep -q '"known":true' "$T/j.out"; }
t "status --json carries budget, builders and known"            json_shape

printf 'builder-budget: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
