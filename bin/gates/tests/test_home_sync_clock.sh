#!/usr/bin/env bash
# test_home_sync_clock.sh — the clock commits the records the house writes itself, and holds on anything else.
# Runs against a throwaway home and a throwaway remote; never touches the real home.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PASS=0; FAIL=0
check() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git init -q --bare -b main "$T/remote.git"
git clone -q "$T/remote.git" "$T/home" 2>/dev/null
cd "$T/home" || exit 1
mkdir -p hodd/memory/comms
echo a >hodd/memory/runes_audit.md; echo '{}' >hodd/memory/comms/telegram.jsonl; echo x >notes.md
git add . && git -c user.name=t -c user.email=t@t commit -qm init && git push -q origin main
clock() { YMIR_HOME="$T/home" bash "$ROOT/bin/vault/home-sync-clock.sh" >/dev/null 2>&1; }
# 1. a dirty runes ledger and a dirty comms log are committed and pushed (2026-11-13: the comms log held the clock)
echo b >>hodd/memory/runes_audit.md; echo '{"m":1}' >>hodd/memory/comms/telegram.jsonl
clock; check $? "records committed and pushed"
[ -z "$(git status --porcelain)" ]; check $? "tree clean after the clock"
[ "$(git rev-list --count origin/main..HEAD)" = 0 ]; check $? "nothing left unpushed"
# 2. any other dirty file holds the clock, and nothing is committed
echo y >>notes.md; echo c >>hodd/memory/runes_audit.md
before=$(git rev-parse HEAD)
clock; [ $? = 3 ]; check $? "a scratch file holds the clock (exit 3)"
[ "$(git rev-parse HEAD)" = "$before" ]; check $? "nothing committed when held"
printf 'test_home_sync_clock: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
