#!/usr/bin/env bash
# data-home.sh test — two checkouts of the hall share ONE data home, and nothing is ever lost (plan 275 S5).
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/data-home.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
export BILSKIRNIR_DATA_HOME="$T/home"
# FENCE: the door also looks at the pinned runtime and the main tree; point both inside the temp folder so this test
# can never reach a real hall (2026-11-12: an unfenced run moved the pin's own hall into the temp folder)
export YMIR_RUNTIME_DIR="$T/no-pin"; export HOME="$T/fake-home"; mkdir -p "$HOME"
mk() { mkdir -p "$T/$1/apps/bilskirnir/scripts"; cp "$SRC" "$T/$1/apps/bilskirnir/scripts/"; }
mk work; mk pin
W="$T/work/apps/bilskirnir"; P="$T/pin/apps/bilskirnir"

# the working tree has the operator's real hall
mkdir -p "$W/data/engines/agent1"; printf 'agents-and-conversations\n' > "$W/data/grokbot.db"; printf 'KEY=x\n' > "$W/.env"
bash "$W/scripts/data-home.sh" --check >/dev/null; [ $? = 1 ] && ok "--check says a change is owed and changes nothing" || bad "check"
[ -d "$W/data" ] && [ ! -L "$W/data" ] && ok "--check left the data where it was" || bad "check moved data"

bash "$W/scripts/data-home.sh" >/dev/null
[ -L "$W/data" ] && [ "$(cat "$W/data/grokbot.db")" = agents-and-conversations ] && ok "the first checkout's data moves into the home and is linked" || bad "first move"
[ -L "$W/.env" ] && grep -q KEY=x "$T/home/.env" && ok "its .env moves too" || bad ".env move"

# the pin started on its own and made an empty hall before the fix
mkdir -p "$P/data"; printf 'empty-hall\n' > "$P/data/grokbot.db"
bash "$P/scripts/data-home.sh" >/dev/null
[ "$(cat "$P/data/grokbot.db")" = agents-and-conversations ] && ok "the pin now opens the operator's hall" || bad "pin not linked"
ls -d "$P"/data.aside-* >/dev/null 2>&1 && [ "$(cat "$P"/data.aside-*/grokbot.db)" = empty-hall ] && ok "the pin's own copy is set aside, not deleted" || bad "pin copy lost"

out=$(bash "$P/scripts/data-home.sh" --check); [ $? = 0 ] && ok "a linked checkout checks clean ($out)" || bad "linked check: $out"
bash "$P/scripts/data-home.sh" >/dev/null; [ "$(find "$P" -maxdepth 1 -name "data.aside-*" | wc -l)" = 1 ] && ok "running again changes nothing" || bad "not idempotent"

# the real hall is chosen even when the EMPTY checkout runs first (the pin's icon is clicked before anything else)
export BILSKIRNIR_DATA_HOME="$T/home2"
mk work2; mk pin2
W2="$T/work2/apps/bilskirnir"; P2="$T/pin2/apps/bilskirnir"
mkdir -p "$W2/data"; head -c 50000 /dev/zero | tr '\0' 'x' > "$W2/data/grokbot.db"; printf 'KEY=real\n' > "$W2/.env"
mkdir -p "$P2/data"; printf 'empty\n' > "$P2/data/grokbot.db"
BILSKIRNIR_CANDIDATES="$W2" bash "$P2/scripts/data-home.sh" >/dev/null
[ "$(stat -c %s "$T/home2/data/grokbot.db")" = 50000 ] && ok "the pin running first still adopts the larger, real hall" || bad "the empty hall won"
[ -L "$W2/data" ] && ok "the donor checkout is linked to the home where its data was" || bad "donor not linked"
grep -q KEY=real "$T/home2/.env" && ok "the real .env came with it" || bad ".env not carried"
ls -d "$P2"/data.aside-* >/dev/null 2>&1 && ok "the empty hall is set aside, not deleted" || bad "empty hall lost"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
