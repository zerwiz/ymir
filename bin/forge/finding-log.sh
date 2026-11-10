#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }; done; unset _c
fi
STATE=""; hoard_state_dir STATE 2>/dev/null || true
[ -n "$STATE" ] || { echo "finding-log: state dir unresolved" >&2; exit 1; }
CONFIG="${YMIR_HOME:-}/config/review-learning.yaml"
[ -r "$CONFIG" ] || CONFIG="$YMIR_HOME/config/review-learning.yaml"

die(){ echo "finding-log: $*" >&2; exit 1; }
usage(){ echo "finding-log: $*" >&2; exit 2; }

ACTION="${1-}"; shift || true
[ "$ACTION" = "add" ] || usage "usage: finding-log.sh add --class C --rule R --file F --pr N --head SHA"

CLASS=""; RULE=""; FILE=""; PR=""; HEAD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --class) CLASS="$2"; shift 2;;
    --rule) RULE="$2"; shift 2;;
    --file) FILE="$2"; shift 2;;
    --pr) PR="$2"; shift 2;;
    --head) HEAD="$2"; shift 2;;
    *) usage "unknown arg $1";;
  esac
done
[ -n "$CLASS" ] && [ -n "$RULE" ] && [ -n "$FILE" ] && [ -n "$PR" ] && [ -n "$HEAD" ] || usage "missing required args"

CLASSES=$(python3 - "$CONFIG" <<'PY'
import sys
p=sys.argv[1]
classes=[]
incls=False
for line in open(p):
    s=line.rstrip('\n')
    if s.strip()=='classes:':
        incls=True; continue
    if incls:
        if s.strip()=='' : continue
        if not s.startswith(' ') and not s.startswith('\t'):
            break
        t=s.strip()
        if t.startswith('- '):
            classes.append(t[2:].strip())
print('\n'.join(classes))
PY
)
echo "$CLASSES" | grep -qx "$CLASS" || { echo "finding-log: class not in vocabulary: $CLASS"; echo "vocabulary:"; echo "$CLASSES"; exit 3; }

mkdir -p "$STATE"
LOG="$STATE/review-findings.jsonl"
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 - "$LOG" "$CLASS" "$RULE" "$FILE" "$PR" "$HEAD" "$DATE" <<'PY'
import json,sys
log,cls,rule,f,pr,head,date=sys.argv[1:]
obj={"class":cls,"rule":rule,"file":f,"pr":int(pr) if str(pr).isdigit() else pr,"head":head,"date":date}
with open(log,"a") as fh:
    fh.write(json.dumps(obj)+"\n")
PY
echo "finding-log: appended $CLASS"
