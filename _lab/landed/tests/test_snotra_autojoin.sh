#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
DOOR="$ROOT/bin/time/snotra/snotra-autojoin.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }
check(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
refute(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then bad "$n" "expected failure"; else ok "$n"; fi; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"; mkdir -p "$YMIR_HOME/hodd/state/calendar"
export AUTOJOIN_NOW="2026-10-20T09:00:00+03:00" AUTOJOIN_WINDOW_HOURS=24 AUTOJOIN_MAX_PER_RUN=3
cat > "$TMP/events.json" <<'JSON'
{"events":[
 {"id":"m1","summary":"Synteon roadmap","start":"2026-10-20T10:00:00+03:00","end":"2026-10-20T11:00:00+03:00","status":"confirmed","busy":true,"conference_url":"https://meet.google.com/abc-defg-hij","workspace":"work","account":"work"},
 {"id":"m2","summary":"Declined call","start":"2026-10-20T11:00:00+03:00","end":"2026-10-20T11:30:00+03:00","status":"confirmed","busy":true,"conference_url":"https://meet.google.com/x","workspace":"work","self_response":"declined"},
 {"id":"m3","summary":"No link","start":"2026-10-20T12:00:00+03:00","end":"2026-10-20T12:30:00+03:00","status":"confirmed","busy":true,"workspace":"work"},
 {"id":"m4","summary":"Dentist","start":"2026-10-20T13:00:00+03:00","end":"2026-10-20T13:30:00+03:00","status":"confirmed","busy":true,"conference_url":"https://meet.google.com/y","workspace":"personal"},
 {"id":"m5","summary":"Private thing","start":"2026-10-20T14:00:00+03:00","end":"2026-10-20T14:30:00+03:00","status":"confirmed","busy":true,"visibility":"private","conference_url":"https://meet.google.com/z","workspace":"work"},
 {"id":"m6","summary":"1:1 with Craig","start":"2026-10-20T15:00:00+03:00","end":"2026-10-20T15:30:00+03:00","status":"confirmed","busy":true,"conference_url":"https://meet.google.com/b","workspace":"work"},
 {"id":"m7","summary":"Patent counsel","start":"2026-10-20T16:00:00+03:00","end":"2026-10-20T17:00:00+03:00","status":"confirmed","busy":true,"conference_url":"https://meet.google.com/c","workspace":"work","classification":"restricted"},
 {"id":"m8","summary":"All day","start":"2026-10-20","end":null,"status":"confirmed","busy":true,"all_day":true,"conference_url":"https://meet.google.com/d","workspace":"work"},
 {"id":"m9","summary":"Ping room","start":"2026-10-20T10:30:00+03:00","end":"2026-10-20T11:00:00+03:00","status":"confirmed","busy":true,"conference_url":"https://ping.zerwiz.org/room","workspace":"work"},
 {"id":"m10","summary":"Zoom call","start":"2026-10-20T17:00:00+03:00","end":"2026-10-20T18:00:00+03:00","status":"confirmed","busy":true,"conference_url":"https://us02web.zoom.us/j/123","workspace":"work"},
 {"id":"m11","summary":"Fourth eligible","start":"2026-10-20T18:00:00+03:00","end":"2026-10-20T18:30:00+03:00","status":"confirmed","busy":true,"conference_url":"https://meet.google.com/e","workspace":"work"}
]}
JSON
check "scan builds a plan" "$DOOR" scan --events "$TMP/events.json"
PLAN="$YMIR_HOME/hodd/state/snotra/autojoin-plan.json"
check "plan is valid json" python3 -c "import json;json.load(open('$PLAN'))"
check "meet is joined" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m1']['decision']=='join'"
check "declined is skipped" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m2']['decision']=='skip' and 'declined' in m['m2']['reason']"
check "no link is skipped" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m3']['reason']=='no video link'"
check "personal lane is off by default" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert 'not enabled' in m['m4']['reason']"
check "private is skipped" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m5']['reason']=='private event'"
check "blocked title is skipped" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m6']['reason']=='blocked title'"
check "restricted is skipped" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m7']['reason']=='restricted'"
check "all-day is skipped" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m8']['reason']=='all-day'"
check "ping platform is detected" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m9']['platform']=='ping' and m['m9']['decision']=='join'"
check "zoom is joinable" python3 -c "
import json;d=json.load(open('$PLAN'));m={p['id']:p for p in d['plan']};assert m['m10']['decision']=='join'"
check "max per run caps the joins" python3 -c "
import json;d=json.load(open('$PLAN'));j=[p for p in d['plan'] if p['decision']=='join'];assert len(j)==3, len(j)"
check "dry run prints WOULD-JOIN" bash -c "'$DOOR' run | grep -q WOULD-JOIN"
check "dry run does not record a join" test ! -s "$YMIR_HOME/hodd/state/snotra/autojoin-joined.json"
check "status prints the plan" bash -c "'$DOOR' status | grep -q 'plan\\[1\\]'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
