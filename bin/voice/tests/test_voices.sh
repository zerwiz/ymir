#!/usr/bin/env bash
# test_voices.sh — the voices door lists, resolves by name, refuses an ambiguous name and writes its catalogue.
# Fenced: the engine is never run (VOICES_FIXTURE names the list), and HOME and YMIR_HOME point into a
# throwaway folder, so the operator's home is never written.
set -u
SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOOR="$SELF/../voices.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" YMIR_HOME="$tmp/ymirhome" XDG_CONFIG_HOME="$tmp/config"
mkdir -p "$HOME" "$YMIR_HOME/hodd/identity"
printf '{"voices": ["af_heart", "am_eric", "bm_george", "em_santa", "am_santa", "zf_xiaobei"]}' > "$tmp/voices.json"
export VOICES_FIXTURE="$tmp/voices.json"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1 — want [$3] got [$2]"; fi; }

check "list counts every voice" "$(bash "$DOOR" list | head -1)" 'voices[6]{id,name,language,gender,lang}:'
check "eric resolves by name" "$(bash "$DOOR" resolve eric)" "am_eric"
check "an id resolves as itself" "$(bash "$DOOR" resolve bm_george)" "bm_george"
bash "$DOOR" resolve santa >/dev/null 2>&1; check "an ambiguous name is refused (exit 3)" "$?" "3"
bash "$DOOR" resolve nobody >/dev/null 2>&1; check "an unknown name is refused (exit 3)" "$?" "3"
check "the lang code follows the prefix" \
  "$(bash "$DOOR" list --json | python3 -c 'import json,sys;print({v["id"]:v["lang"] for v in json.load(sys.stdin)["voices"]}["zf_xiaobei"])')" "cmn"
bash "$DOOR" catalogue --home >/dev/null
check "the catalogue lands in the hoard" "$(sed -n 3p "$YMIR_HOME/hodd/identity/voices.yaml")" "count: 6"
check "no temp file is left" "$(find "$YMIR_HOME/hodd/identity" -name '*.tmp' | wc -l)" "0"
bash "$DOOR" >/dev/null 2>&1; check "no verb is a usage error (exit 2)" "$?" "2"
# a choice per context (plan 326.3): kept in the home, checked against the pack, refused by name when unknown
printf '{"voice": "af_heart"}' > "$tmp/kokoro.json"; export KOKORO_CONFIG="$tmp/kokoro.json"
check "with nothing kept, a context speaks in the engine's default" "$(bash "$DOOR" for rodd)" "af_heart"
bash "$DOOR" choose rodd eric >/dev/null
check "a choice is kept by its id" "$(bash "$DOOR" for rodd)" "am_eric"
check "the choice lands in the home's config" "$(grep -c '^rodd: am_eric$' "$YMIR_HOME/config/voices.yaml")" "1"
bash "$DOOR" choose default bm_george >/dev/null
check "an unnamed context falls to the kept default" "$(bash "$DOOR" for snotra)" "bm_george"
check "a person falls to the default too" "$(bash "$DOOR" for person.ada)" "bm_george"
bash "$DOOR" choose rodd nobody >/dev/null 2>&1; check "an unknown voice is refused by name (exit 3)" "$?" "3"
check "a refused choice changes nothing" "$(bash "$DOOR" for rodd)" "am_eric"
bash "$DOOR" choose 'Bad Name!' eric >/dev/null 2>&1; check "a malformed context is a usage error (exit 2)" "$?" "2"
# the generated catalogue is read back when fresh, and a newer pack makes it stale
unset VOICES_FIXTURE; export KOKORO_BIN=/nonexistent KOKORO_VOICES="$tmp/pack.bin"; touch -d '1 hour ago' "$tmp/pack.bin"
check "a fresh catalogue answers without the engine" "$(bash "$DOOR" resolve eric)" "am_eric"
touch "$tmp/pack.bin"; touch -d '2 hours ago' "$YMIR_HOME/hodd/identity/voices.yaml"
bash "$DOOR" resolve eric >/dev/null 2>&1; check "a pack newer than the catalogue asks the engine (absent here: exit 1)" "$?" "1"
echo "test_voices: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
