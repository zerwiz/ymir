#!/usr/bin/env bash
# test_arm_pin_board.sh — plan 257 H8: the pin's age and reach as one fact (bin/pi/arm-pin.sh).
#
#   1. a pin one commit behind its origin: `status` prints `pin <sha> · 1 behind`, `check` fails "pin behind"
#   2. fast-forwarded, clean, every recorded supervisor inside it: `check` passes
#   3. an arm client running a working tree: `check` names it "runs outside the pin"
#   4. a dirty pin and an off-branch pin are named
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
DOOR="$ROOT/bin/pi/arm-pin.sh"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" YMIR_HOME="$T/ymirhome"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset YMIR_RUNTIME_DIR YMIR_RUNTIME_BRANCH 2>/dev/null || true
mkdir -p "$HOME" "$YMIR_HOME/config"
git init -q -b main "$T/origin-work" && git -C "$T/origin-work" commit -q --allow-empty -m one
git clone -q --bare "$T/origin-work" "$T/origin.git"
git clone -q "$T/origin.git" "$T/pin"
git -C "$T/origin-work" remote add origin "$T/origin.git"
git -C "$T/origin-work" commit -q --allow-empty -m two && git -C "$T/origin-work" push -q origin main
printf 'YMIR_RUNTIME_DIR="%s"\nYMIR_RUNTIME_BRANCH="main"\n' "$T/pin" >"$YMIR_HOME/config/runtime.env"
: >"$T/supervisors"
export ARM_PIN_SUPERVISORS="$T/supervisors"
git -C "$T/pin" fetch -q origin

# 1
out="$(bash "$DOOR" status)"
t "status is one line: pin <sha> · 1 behind" grep -qE '^pin [0-9a-f]{8} · 1 behind$' <<<"$out"
out="$(bash "$DOOR" check --no-fetch)"; rc=$?
t "a pin behind fails the check" [ "$rc" -eq 1 ]
t "the finding names the count" grep -q '"pin behind",".* 1 behind origin/main' <<<"$out"

# 2
git -C "$T/pin" merge -q --ff-only origin/main
printf 'arm-client(pid 1)\t%s/bin/pi/syn-watch-arm.sh\nunit(ymir-syn-watch.service)\t%s/bin/pi/syn-watch.sh\n' "$T/pin" "$T/pin" >"$T/supervisors"
out="$(bash "$DOOR" check)"; rc=$?
t "current, clean, every surface inside: ok" [ "$rc" -eq 0 ]
t "ok names 0 behind" grep -q '0 behind' <<<"$out"

# 3
printf 'arm-client(pid 2)\t/home/someone/ymir/bin/pi/syn-watch-arm.sh\n' >>"$T/supervisors"
out="$(bash "$DOOR" check --no-fetch)"; rc=$?
t "a working-tree arm client fails the check" [ "$rc" -eq 1 ]
t "it is named" grep -q '"runs outside the pin","arm-client(pid 2) executes /home/someone/ymir' <<<"$out"

# 4
printf 'arm-client(pid 1)\t%s/bin/pi/syn-watch-arm.sh\n' "$T/pin" >"$T/supervisors"
touch "$T/pin/stray"
out="$(bash "$DOOR" check --no-fetch)"
t "a dirty pin is named" grep -q '"pin dirty"' <<<"$out"
rm -f "$T/pin/stray"; git -C "$T/pin" checkout -q -b side
out="$(bash "$DOOR" check --no-fetch)"
t "an off-branch pin is named" grep -q '"pin off its branch",".* stands on side, not main' <<<"$out"

# no pin at all
rm -f "$YMIR_HOME/config/runtime.env"
out="$(bash "$DOOR" status)"; rc=$?
t "no pin: status says so, non-zero" [ "$rc" -eq 1 ]
t "no pin: named" grep -q '^pin none' <<<"$out"

printf 'test_arm_pin_board: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
