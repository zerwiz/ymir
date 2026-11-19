#!/usr/bin/env bash
# test_garmr_identity_named.sh — a CRITICAL must name what changed, or it is not a CRITICAL.
#
# WHY (2026-11-20). On this machine the identity watch fired every 15-30 minutes with an empty target —
# the line read `changed  at …` with nothing between — and every one was announced as "passwd, shadow,
# sudoers or an authorised key changed". Nothing had named a file. An alarm that cannot say what it saw
# trains the operator to ignore the one alarm that must never be ignored, so the rule now reports an
# unnamed target as HIGH and says plainly that no file is named, while a named path stays CRITICAL.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
pass=0; fail=0
t() { local n="$1"; shift; if "$@"; then printf '  ok   %s\n' "$n"; pass=$((pass+1)); else printf '  FAIL %s\n' "$n"; fail=$((fail+1)); fi; }

verdict() {  # <target> -> "<severity>|<does the line name passwd/shadow/sudoers>"
  TARGET="$1" python3 - "$ROOT" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], 'bin/ward/garmr'))
import rules
f = {"kind": "file_change", "class": "identity", "comm": "chmod", "pid": 1, "uid": 1000,
     "ts": "2026-11-20T01:00:00Z", "target": os.environ["TARGET"]}
r = rules.evaluate(f, {})
# "says what changed" = the sentence names the file it claims moved. An unnamed record says so
# instead, which is the whole point: it must not read as a change at all.
claimed = "changed /" in r["line"]
named_no_path = "no path in the record" in r["line"]
print(f'{r["severity"]}|{"changed" if claimed else ("unnamed" if named_no_path else "other")}')
PY
}

unnamed_is_not_critical()      { [ "$(verdict '')" = "HIGH|unnamed" ]; }
named_path_is_critical()       { [ "$(verdict '/etc/sudoers')" = "CRITICAL|changed" ]; }
other_identity_still_critical(){ [ "$(verdict '/etc/shadow')" = "CRITICAL|changed" ]; }

t "an identity record with no path is HIGH and claims no file"        unnamed_is_not_critical
t "a named path is still CRITICAL and names the class of file"        named_path_is_critical
t "another identity file is judged the same way"                      other_identity_still_critical

printf 'garmr-identity: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
