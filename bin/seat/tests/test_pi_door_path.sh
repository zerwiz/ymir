#!/usr/bin/env bash
# The ward for the pi door's PATH block (bin/seat/harness-extensions-install.sh).
#
# The fault (measured 2026-11-19): the old block prepended the door ONCE, and mise's activate
# hook rewrote PATH at every prompt with its own pi install first. `which -a pi` named mise's
# install first and the door third, and `pi` in ~/ymir loaded two extension trees and
# refused both. The block must keep the door first AFTER every prompt hook, and an install
# must replace an older block marker to marker without touching the operator's own lines.
#
# Everything runs in a fenced HOME with a fake mise hook and fake pi binaries.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
inst="$here/../harness-extensions-install.sh"
ok=0; fail=0
pass() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
flunk() { fail=$((fail+1)); printf 'FAIL %s\n     %s\n' "$1" "${2-}"; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export HOME="$work/home" SHELL=/bin/bash
mkdir -p "$HOME/.pi/agent/bin" "$work/mise/bin"
for d in "$HOME/.pi/agent/bin" "$work/mise/bin"; do printf '#!/bin/sh\necho %s\n' "$d" >"$d/pi"; chmod +x "$d/pi"; done

# The installer's own functions, taken from the file itself (never a copy of them in this test).
fns="$(sed -n '/^PI_DOOR_MARK=/,/^if command -v pi /p' "$inst" | sed '$d')"
[ -n "$fns" ] || { printf 'FAIL the PATH-block functions were not found in %s\n' "$inst"; exit 1; }
eval "$fns"

# The operator's rc: a mise-like prompt hook that puts its own pi first, then the OLD v1 block.
cat >"$HOME/.bashrc" <<EOF
# operator line one
_mise_hook() { case ":\$PATH:" in ":$work/mise/bin:"*) ;; *) PATH="$work/mise/bin:\$PATH" ;; esac; }
PROMPT_COMMAND="_mise_hook"
# >>> ymir pi door >>>
case ":\$PATH:" in ":\$HOME/.pi/agent/bin:"*) ;; *) export PATH="\$HOME/.pi/agent/bin:\$PATH" ;; esac
# <<< ymir pi door <<<
# operator line two
EOF
cp "$HOME/.bashrc" "$HOME/.profile"

resolve() { env -i HOME="$HOME" PATH=/usr/bin:/bin bash -c 'source "$HOME/.bashrc"; eval "$PROMPT_COMMAND"; command -v pi'; }

before="$(resolve)"
[ "$before" = "$work/mise/bin/pi" ] && pass "the old block loses to the prompt hook (the measured fault)" \
  || flunk "the old block loses to the prompt hook (the measured fault)" "resolved $before"
[ "$(pi_door_path_state)" = stale ] && pass "an older block reads stale" || flunk "an older block reads stale" "$(pi_door_path_state)"

pi_door_path_seat && pass "the seat ran" || flunk "the seat ran" "rc=$?"
[ "$(pi_door_path_state)" = written ] && pass "the block is current after the seat" || flunk "the block is current after the seat" "$(pi_door_path_state)"
[ "$(grep -c '^# >>> ymir pi door >>>' "$HOME/.bashrc")" = 1 ] && pass "one block, replaced in place" \
  || flunk "one block, replaced in place" "$(grep -c 'ymir pi door >>>' "$HOME/.bashrc")"
grep -q '^# operator line one' "$HOME/.bashrc" && grep -q '^# operator line two' "$HOME/.bashrc" \
  && pass "the operator's own lines are untouched" || flunk "the operator's own lines are untouched" "$(cat "$HOME/.bashrc")"
[ -f "$HOME/.bashrc.bak-ymir-pi-door" ] && pass "a backup of the old rc is kept" || flunk "a backup of the old rc is kept"

after="$(resolve)"
[ "$after" = "$HOME/.pi/agent/bin/pi" ] && pass "after the prompt hook, pi is the door" \
  || flunk "after the prompt hook, pi is the door" "resolved $after"
n="$(env -i HOME="$HOME" PATH=/usr/bin:/bin bash -c 'source "$HOME/.bashrc"; eval "$PROMPT_COMMAND"; eval "$PROMPT_COMMAND"; printf "%s" "$PATH" | tr ":" "\n" | grep -cx "$HOME/.pi/agent/bin"')"
[ "$n" = 1 ] && pass "the door sits on PATH exactly once" || flunk "the door sits on PATH exactly once" "count $n"

sum1="$(md5sum <"$HOME/.bashrc")"
pi_door_path_seat && [ "$sum1" = "$(md5sum <"$HOME/.bashrc")" ] && pass "a second seat changes nothing" \
  || flunk "a second seat changes nothing"

printf '\n%s passed, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]
