#!/usr/bin/env bash
# test_a2a_prove.sh — one nonce, three doors, and a prover that says UNPROVED out loud.
#
# Why this test exists: this house has twice called a channel good because a card answered.
# The prover must therefore fail loudly and name what did not answer — a green that only
# shows a delivered file is not a pass. Everything runs in a temporary queue; no agent is
# woken and no real pane is typed into.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../a2a-talk.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_a2a_prove"
[ -x "$door" ] || { bad "the door is missing: $door"; exit 1; }

export HOME="$tmp/home"; mkdir -p "$HOME"
export RATATOSKR_QUEUE="$tmp/queue"

# 1 · the plumbing proof runs all three doors and keeps the nonce
out="$("$door" prove --nonce 1234abcd 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "the three doors prove" || bad "prove exited $rc: $out"
printf '%s' "$out" | grep -q '^nonce: 1234abcd' && ok "the nonce is the one the caller gave" || bad "nonce: $out"
for d in queue relay arm; do
  printf '%s' "$out" | grep -q "\"$d\",\"proved\"" && ok "the $d door is proved" || bad "the $d door: $out"
done

# 2 · the nonce really is carried, and it is in the file that proves it
printf '%s' "$out" | grep -q 'nonce intact' && ok "the nonce is intact at the end of the crossing" || bad "no nonce evidence: $out"
ls "$RATATOSKR_QUEUE"/done/*.md >/dev/null 2>&1 && ok "the proof leaves the answered task as its record" || bad "no task left in done/"

# 3 · a nonce is generated when none is given, so a caller need not invent one
out="$("$door" prove 2>&1)"
printf '%s' "$out" | grep -Eq '^nonce: [0-9a-f]{8,}$' && ok "a proof without --nonce invents one" || bad "generated nonce: $out"

# 4 · a door that cannot answer is FAILED and NAMED, and the exit code says so
mv "$RATATOSKR_QUEUE" "$tmp/queue-away"
mkdir -p "$RATATOSKR_QUEUE"
chmod 500 "$RATATOSKR_QUEUE"          # the queue cannot be written
out="$("$door" prove --nonce deadb33f 2>&1)"; rc=$?
chmod 700 "$RATATOSKR_QUEUE"
[ "$rc" = 1 ] && ok "a failed door exits 1" || bad "a failed door exited $rc"
printf '%s' "$out" | grep -q 'not proved:' && ok "a failed door is named in the summary" || bad "no summary: $out"

# 5 · --live with a target that never answers says UNPROVED, by name, and does not pretend
out="$(RATATOSKR_QUEUE="$tmp/live" "$door" prove --live w0:p0 w0:p1 --nonce ffffffff --wait 1 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'UNPROVED' && ok "--live says UNPROVED rather than a green" || bad "live: $out"
printf '%s' "$out" | grep -q 'w0:p0' && ok "the unproved hop names the agent it waited for" || bad "no agent named: $out"
[ "$rc" = 1 ] && ok "an unproved round trip exits 1" || bad "unproved exited $rc"

# 6 · --live without two agents is a usage error, not a silent pass
"$door" prove --live >/dev/null 2>&1; [ $? = 2 ] && ok "--live without two agents exits 2" || bad "--live usage exited $?"

printf '\ntest_a2a_prove: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
