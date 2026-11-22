#!/usr/bin/env bash
# test_contracts.sh — plan 350 F: the behaviour contracts.
#   · the runner reads ok / red / skip, and a contract that hangs is red, named as hung
#   · check keeps the reading, says a red once on its TURN, and the trouble panel's `contracts` row carries it
#   · the review contract catches one head handed to review over and over (tonight's evidence), and passes twice
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/c" "$T/state" "$T/home"
printf '#!/usr/bin/env bash\necho "ok: fine"\n' >"$T/c/10-good.sh"
printf '#!/usr/bin/env bash\necho "red: broken — look here"; exit 1\n' >"$T/c/20-bad.sh"
printf '#!/usr/bin/env bash\necho "skip: not here"\n' >"$T/c/30-away.sh"
printf '#!/usr/bin/env bash\nsleep 5; echo "ok: late"\n' >"$T/c/40-slow.sh"
export CONTRACTS_DIR="$T/c" CONTRACTS_HOST=host-a YMIR_STATE_DIR="$T/state" YMIR_HOME="$T/home" CONTRACT_TIMEOUT_S=2
C="$root/bin/ward/contracts.sh"
echo "test_contracts"
out="$("$C" run 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "a red contract makes the run red" || bad "rc=$rc"
printf '%s' "$out" | grep -q '"host-a","good","ok"' && ok "ok is read" || bad "good: $out"
printf '%s' "$out" | grep -q '"host-a","bad","red","red: broken — look here"' && ok "red is read with its line" || bad "bad"
printf '%s' "$out" | grep -q '"host-a","away","skip"' && ok "skip is read, and is not red" || bad "skip"
printf '%s' "$out" | grep -q '"host-a","slow","red","red: the contract hung (over 2s)"' && ok "a contract that hangs is red, named as hung" || bad "slow: $out"
out="$("$C" check 2>&1)"
printf '%s' "$out" | grep -q 'turned red on host-a' && ok "a turn to red is said" || bad "turn: $out"
out="$("$C" check 2>&1)"
printf '%s' "$out" | grep -q 'turned red' && bad "a red that stays red was said again" || ok "a red that stays red is not said twice"
out="$(TROUBLE_HOST=host-a python3 "$root/bin/ward/trouble.py" "$root" "$T/home" "$T/state" read --only contracts 2>&1)"
printf '%s' "$out" | grep -q 'RED' && printf '%s' "$out" | grep -q 'bad: broken' && ok "the trouble panel's contracts row carries the reds" || bad "panel: $out"

# the review contract on tonight's evidence
now="$(date +%s)"; iso="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
for i in 1 2 3 4; do printf '%s 7 report rv-%s judge: review o/r#5 head abcdef1234567890 handed by the review-watch\n' "$now" "$i"; done >"$T/state/.wake-queue"
printf '%s held: review o/r#6 head 1111111111111111 handed\n' "$iso" >"$T/state/reviews-held.log"
out="$(YMIR_STATE="$T/state" bash "$root/bin/ward/contracts.d/30-review-once-per-head.sh")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'o/r#5@abcdef123456 was handed to review 4 times' && ok "a head handed to review four times is red" || bad "review: rc=$rc $out"
printf '%s 7 report x judge: review o/r#5 head abcdef1234567890\n' "$((now - 200000))" >"$T/state/.wake-queue"
YMIR_STATE="$T/state" bash "$root/bin/ward/contracts.d/30-review-once-per-head.sh" >/dev/null && ok "an old repeat outside the window is not red" || bad "window"
echo "test_contracts: $pass passed, $fail failed"
[ "$fail" = 0 ]
