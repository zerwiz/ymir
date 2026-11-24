#!/usr/bin/env bash
# `release.sh build --ref main` builds the REMOTE main, and `--from` accepts a URL (plan 366). Resolution only: nothing is built.
set -u
ROOT="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; export YMIR_RELEASES="$T/rel" YMIR_RELEASE_RESOLVE_ONLY=1 HOME="$T/h"; mkdir -p "$HOME"
g() { git -c user.email=a@b -c user.name=t "$@"; }
g init -q --bare "$T/origin.git"; g clone -q "$T/origin.git" "$T/work" 2>/dev/null
( cd "$T/work" && echo 1 >f && g add f && g commit -qm one && g branch -M main && g push -q origin main 2>/dev/null )
g clone -q "$T/origin.git" "$T/runtime" 2>/dev/null
( cd "$T/work" && echo 2 >f && g commit -qam two && g push -q origin main 2>/dev/null )
want="$(g -C "$T/origin.git" rev-parse --short=12 main)"; stale="$(g -C "$T/runtime" rev-parse --short=12 main)"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
[ "$want" != "$stale" ] || bad "the fixture has no stale main"
got="$(bash "$ROOT/bin/engine/release.sh" build --from "$T/runtime" --ref main 2>&1 | sed -n 's/^resolved.//p')"
[ "$got" = "$want" ] && ok "--ref main builds the remote main, not the stale local one" || bad "got '$got', want $want"
got="$(bash "$ROOT/bin/engine/release.sh" build --from "file://$T/origin.git" --ref main 2>&1 | sed -n 's/^resolved.//p')"
[ "$got" = "$want" ] && ok "--from accepts a URL" || bad "url: got '$got', want $want"
rm -rf "$T"; exit $fail
