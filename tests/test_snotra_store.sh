#!/usr/bin/env bash
# Tests for snotra-store.sh. Run: bash tests/test_snotra_store.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STORE="$ROOT/bin/time/snotra/snotra-store.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }
check(){ local name=$1; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
refute(){ local name=$1; shift; if "$@" >/dev/null 2>&1; then bad "$name" "expected failure"; else ok "$name"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"; mkdir -p "$YMIR_HOME/hodd/life/meetings"
git -C "$YMIR_HOME" init -q
printf 'hodd/life/meetings/**/audio/\n*.wav\n' > "$YMIR_HOME/.gitignore"
git -C "$YMIR_HOME" add .gitignore && git -C "$YMIR_HOME" -c user.email=t@t -c user.name=t commit -qm init

D1="$("$STORE" new work "Roadmap and Trello" --title "Road map & Trello" --date 2026-10-20 --source ping --platform ping --classification confidential --account work --consent announced)"
ID1="$(basename "$D1")"
check "new creates the directory" test -d "$D1"
check "meeting.json exists" test -s "$D1/meeting.json"
check "schema is 1" test "$(python3 -c "import json;print(json.load(open('$D1/meeting.json'))['schema'])")" = 1
check "workspace is the lane" test "$(python3 -c "import json;print(json.load(open('$D1/meeting.json'))['workspace'])")" = work
check "state is captured" test "$(cat "$D1/.state")" = captured

D2="$("$STORE" new personal "Dentist" --title "Dentist" --date 2026-10-21 --source ear --platform local --classification private --account personal)"
ID2="$(basename "$D2")"
check "personal lane exists" test -d "$D2"

printf '[00:00] Alex: hello\n' > "$TMP/t.md"
check "put transcript" "$STORE" put "$ID1" "$TMP/t.md" --as transcript
check "state advanced to transcribed" test "$(cat "$D1/.state")" = transcribed
refute "put refuses to overwrite the record" "$STORE" put "$ID1" "$TMP/t.md" --as transcript

printf 'minutes\n' > "$TMP/m.md"
check "put minutes" "$STORE" put "$ID1" "$TMP/m.md" --as minutes
check "state advanced to recorded" test "$(cat "$D1/.state")" = recorded

check "index generates" "$STORE" index
check "index lists both lanes" bash -c "grep -q '| work |' '$YMIR_HOME/hodd/life/meetings/index.md' && grep -q '| personal |' '$YMIR_HOME/hodd/life/meetings/index.md'"
check "verify --all passes" "$STORE" verify --all

# lane mismatch is refused by verify
python3 - "$D1/meeting.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['workspace']='personal'; json.dump(d,open(p,'w'),indent=2)
PY
refute "lane mismatch fails verify" "$STORE" verify --all
python3 - "$D1/meeting.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['workspace']='work'; json.dump(d,open(p,'w'),indent=2)
PY

# audio: ignored is accepted, un-ignored is refused
printf 'x' > "$TMP/a.wav"
check "audio accepted when git-ignored" "$STORE" put "$ID1" "$TMP/a.wav" --as audio
printf '*.mp3\n' > "$YMIR_HOME/.gitignore"
refute "audio refused when not git-ignored" "$STORE" put "$ID2" "$TMP/a.wav" --as audio

# state and list
check "state transitions" "$STORE" state "$ID2" recorded
check "list --json is valid json" bash -c "'$STORE' list --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d,list) and len(d)==2'"

# path
check "path resolves" bash -c "'$STORE' path '$ID1' | grep -q '$ID1'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
