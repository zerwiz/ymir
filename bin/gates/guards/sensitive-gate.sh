#!/usr/bin/env bash
# sensitive-gate.sh — one gate for every external surface of a sensitive artifact set.
#
#   sensitive-gate.sh <dir> --surface private|email|trello|chat|public|model [--to ADDRS]
#
# Order: classification/hold -> provenance -> private/NDA guard -> access log.
# A failed gate exits 1 and writes the refusal to the artifact set's access log.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DIR="${1-}"; shift || true
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: sensitive-gate.sh <dir> --surface ..." >&2; exit 2; }
SURFACE="private"; TO=""
while [ $# -gt 0 ]; do case "$1" in --surface) SURFACE="${2-}"; shift 2;; --to) TO="${2-}"; shift 2;; *) shift;; esac; done
ACTOR="${USER:-unknown}"; AT="$(date --iso-8601=seconds)"; WHY=""
fail(){ printf 'gate refused: %s\n' "$1" >&2; log refused "$1"; exit 1; }
log(){
  python3 - "$DIR/access.jsonl" "$AT" "$ACTOR" "$SURFACE" "$TO" "$1" "$2" <<'PY'
import json,sys,os
p,at,actor,surface,to,verdict,why=sys.argv[1:]
with open(p,'a') as f: f.write(json.dumps({'at':at,'actor':actor,'surface':surface,'to':to,'verdict':verdict,'why':why},sort_keys=True)+'\n')
os.chmod(p,0o600)
PY
}
# 1. classification and hold
CLASS="$(python3 - "$DIR" <<'PY'
import sys,os
try:
 import yaml
 p=os.path.join(sys.argv[1],'classification.yaml')
 d=yaml.safe_load(open(p,encoding='utf-8')) if os.path.isfile(p) else {}
 print(d.get('classification','') if d else '')
except Exception: print('')
PY
)"
HOLD="$(python3 - "$DIR" <<'PY'
import sys,os
try:
 import yaml
 p=os.path.join(sys.argv[1],'classification.yaml')
 d=yaml.safe_load(open(p,encoding='utf-8')) if os.path.isfile(p) else {}
 print('1' if d.get('hold') else '0')
except Exception: print('0')
PY
)"
case "$CLASS" in
  *patent*|*restricted*|*confidential*) [ "$SURFACE" = private ] || fail "classification $CLASS does not cross to $SURFACE" ;;
esac
[ "$HOLD" = 0 ] || [ "$SURFACE" = private ] || fail "hold is active"
# 2. provenance for held/sensitive sets
if [ "$SURFACE" != private ] && [ -f "$DIR/provenance.json" ]; then
  "$ROOT/bin/time/snotra/snotra-provenance.sh" verify "$DIR" >/dev/null 2>&1 || fail "provenance verify failed"
fi
case "$CLASS" in
  *patent*|*restricted*) [ -f "$DIR/provenance.json" ] || fail "sensitive set has no provenance seal" ;;
esac
# 3. private / NDA guard
if case "$SURFACE" in chat|public|model) true;; *) false;; esac && [ -x "$ROOT/bin/gates/guards/private-guard.sh" ]; then
  "$ROOT/bin/gates/guards/private-guard.sh" scan-meeting "$DIR" --surface "$SURFACE" --to "$TO" >/dev/null 2>&1 || fail "private/NDA guard"
fi
log allowed ""
printf 'gate\tallowed\t%s\t%s\n' "$SURFACE" "$DIR"
