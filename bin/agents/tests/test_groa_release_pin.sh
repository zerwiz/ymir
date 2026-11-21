#!/usr/bin/env bash
# test_groa_release_pin.sh — a pin that is a link to a release is measured, never merged in place (2026-11-20).
# Before: every seat's Gróa read its release as "dirty (4)" (the .run/.a2a/.yggdrasil links and the proof stamp)
# and held the pin; had it been clean, Gróa would have fast-forwarded inside a proved release.
# The function is lifted out of groa-update.sh itself, so the test judges the shipped code.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
G="$ROOT/bin/agents/groa-update.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

src="$(sed -n '/^release_pin_state() {/,/^}/p' "$G")"
[ -n "$src" ] && ok "release_pin_state is in groa-update.sh" || { bad "no release_pin_state"; exit 1; }
eval "$src"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org
mkdir -p "$HOME"
git init -q -b main "$T/origin"
git -C "$T/origin" commit -q --allow-empty -m one
sha="$(git -C "$T/origin" rev-parse HEAD)"; a="$T/rel/${sha:0:12}"
git clone -q "$T/origin" "$a" 2>/dev/null
mkdir -p "$T/shared/.run"; ln -s "$T/shared/.run" "$a/.run"; date > "$a/.release-proved"
ln -s "$a" "$T/pin"
REMOTE=origin BRANCH=main

CHECK=1; release_pin_state "$T/pin"
[ "$FF_STATE" = current ] && ok "a release on main is current, its links and stamp are not dirt" || bad "current: $FF_STATE $FF_DETAIL"

git -C "$T/origin" commit -q --allow-empty -m two
before="$(git -C "$a" rev-parse HEAD)"
CHECK=1; release_pin_state "$T/pin"
[ "$FF_STATE" = behind ] && ok "a check names a release behind main" || bad "check behind: $FF_STATE $FF_DETAIL"
CHECK=0; release_pin_state "$T/pin"
[ "$FF_STATE" = rebuild ] && ok "an apply hands a behind release to the release door" || bad "apply: $FF_STATE $FF_DETAIL"
[ "$(git -C "$a" rev-parse HEAD)" = "$before" ] && ok "the proved release was not merged in place" || bad "the release moved"

git -C "$a" merge -q --ff-only origin/main
CHECK=1; release_pin_state "$T/pin"
case "$FF_STATE:$FF_DETAIL" in behind:*"moved in place"*) ok "a release carrying code it is not named for is named moved-in-place" ;; *) bad "moved in place: $FF_STATE $FF_DETAIL" ;; esac

grep -q 'if \[ -L "\$PIN_DIR" \]; then release_pin_state' "$G" && ok "a linked pin takes the release road" || bad "pin road not wired"
grep -q 'updated|rebuild) PIN_MOVED=1' "$G" && ok "a rebuild moves the pin through runtime-deploy" || bad "rebuild does not move the pin"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
