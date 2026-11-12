#!/usr/bin/env bash
# The ward for "pi loads the pin": every harness binder points at the pinned runtime whichever
# checkout runs it, and the one-home door wins on PATH. All in a temp HOME — nothing real is touched.
#   1. valknut-load --global, run from a WORKING tree, binds the pin (runtime.env holds a literal $HOME)
#   2. with no pin, the working tree is bound
#   3. the installer's PATH block is printed without writing (YMIR_PI_DOOR_PATH=print)
#   4. the installer writes the block once (idempotent) into the profile and the rc
#   5. --check goes stale without the block and clean of that complaint with it
set -u
here="${BASH_SOURCE[0]%/*}"; repo="$(CDPATH='' cd "$here/../../.." && pwd)"
ok=0; fail=0
t() { local n=$1; shift; if "$@" >/dev/null 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; fi; }
w="$(mktemp -d)"; trap 'rm -rf "$w"' EXIT
H="$w/home"; mkdir -p "$H/.pi/agent" "$H/yhome/config" "$H/ymir-runtime/.pi/extensions"
: >"$H/ymir-runtime/.pi/extensions/elder.ts"; git -C "$H/ymir-runtime" init -q 2>/dev/null
printf 'YMIR_RUNTIME_DIR="$HOME/ymir-runtime"\n' >"$H/yhome/config/runtime.env"

HOME="$H" YMIR_HOME="$H/yhome" bash "$repo/bin/seat/valknut-load.sh" --global >/dev/null 2>&1
t "global binds the pin, not the working tree" grep -q "$H/ymir-runtime/.pi/extensions" "$H/.pi/agent/settings.json"
t "the working tree is not named" bash -c "! grep -q '$repo/.pi/extensions' '$H/.pi/agent/settings.json'"

H2="$w/home2"; mkdir -p "$H2/.pi/agent" "$H2/yhome/config"; : >"$H2/yhome/config/runtime.env"
# a stand-in working tree (a sparse worktree carries no .pi/extensions of its own)
F="$w/fake"; mkdir -p "$F/bin/seat" "$F/bin/pi" "$F/RULES" "$F/.agents/agents" "$F/.agents/skills" "$F/.pi/extensions"
cp "$repo/bin/seat/valknut-load.sh" "$F/bin/seat/"; cp "$repo/bin/pi/arm-pin-lib.sh" "$F/bin/pi/"; : >"$F/.pi/extensions/elder.ts"
HOME="$H2" YMIR_HOME="$H2/yhome" bash "$F/bin/seat/valknut-load.sh" --global >/dev/null 2>&1
t "no pin: the working tree is bound" grep -q "$F/.pi/extensions" "$H2/.pi/agent/settings.json"
HOME="$H" YMIR_HOME="$H/yhome" bash "$F/bin/seat/valknut-load.sh" --global >/dev/null 2>&1
t "a pin beats a working tree that has extensions" bash -c "! grep -q '$F/.pi/extensions' '$H/.pi/agent/settings.json'"

printf '#!/bin/sh\n' >"$w/pi"; chmod +x "$w/pi"
inst() { PATH="$w:$PATH" HOME="$H" YMIR_HOME="$H/yhome" SHELL=/bin/bash "$@" bash "$repo/bin/seat/harness-extensions-install.sh" $CHK; }
CHK=""
YMIR_PI_DOOR_PATH=print inst env >"$w/p" 2>&1
t "print mode names the block" grep -q 'ymir pi door' "$w/p"
t "print mode writes nothing" bash -c "[ ! -e '$H/.profile' ] && [ ! -e '$H/.bashrc' ]"
CHK=--check inst env >"$w/c1" 2>&1
t "check is stale before the block" grep -q 'door NOT first on PATH' "$w/c1"
CHK=""; inst env >/dev/null 2>&1; inst env >/dev/null 2>&1
t "block in the profile, once" bash -c "[ \$(grep -c '>>> ymir pi door' '$H/.profile') = 1 ]"
t "block in the rc, once" bash -c "[ \$(grep -c '>>> ymir pi door' '$H/.bashrc') = 1 ]"
CHK=--check inst env >"$w/c2" 2>&1
t "check clean of the PATH complaint after" bash -c "! grep -q 'door NOT first on PATH' '$w/c2'"
printf '\n%s passed, %s failed\n' "$ok" "$fail"; [ "$fail" = 0 ]
