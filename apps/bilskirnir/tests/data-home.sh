#!/usr/bin/env bash
# data-home.sh test — two checkouts of the hall share ONE data home, and nothing is ever lost (plan 275 S5).
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/data-home.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
export BILSKIRNIR_DATA_HOME="$T/home"
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
ls -d "$P"/data.local-* >/dev/null 2>&1 && [ "$(cat "$P"/data.local-*/grokbot.db)" = empty-hall ] && ok "the pin's own copy is set aside, not deleted" || bad "pin copy lost"

out=$(bash "$P/scripts/data-home.sh" --check); [ $? = 0 ] && ok "a linked checkout checks clean ($out)" || bad "linked check: $out"
bash "$P/scripts/data-home.sh" >/dev/null; [ "$(ls -d "$P"/data.local-* | wc -l)" = 1 ] && ok "running again changes nothing" || bad "not idempotent"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
