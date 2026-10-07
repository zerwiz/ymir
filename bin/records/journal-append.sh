#!/usr/bin/env bash
# journal-append.sh — write one idempotent entry to THIS machine's outbox.
#
# Plan 51 (multi-machine operations), Phase 2b. A body works fully offline: every
# write that must reach the heart is committed to the local journal FIRST, then
# pushed when the link returns (bin/records/journal-reconcile.sh). The journal is
# append-only and namespaced by hostname, so the heart can fold many machines'
# journals into ONE record without ever forking a chain (plan 51, Law 7).
#
#   journal-append.sh --op <op> [--data <json>] [--actor <who>] [--namespace <ns>]
#   journal-append.sh --list        # the local journal, as TOON
#   journal-append.sh --version
#
# Entry (one JSON object per line):
#   {"key":"<host>:<seq>:<uuid>","ts":"<iso>Z","actor":"<who>","op":"<op>","data":{…},"ns":"<namespace>"}
# `key` is the idempotency key: a replayed entry is a no-op at the heart.
# `ns` scopes the entry to a COMPANY namespace (plan 58, "Several Ymirs, one
# company"); it is present only when --namespace is given. An entry without it
# is the operator's OWN and reads exactly as before — the format is extended,
# never mutated.
#
# Env: YMIR_HOST (defaults to the short hostname), YMIR_STATE_OVERRIDE.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"

# The operator's state: env → hoard → the one documented default (Rule 04/07).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE=""
if command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE 2>/dev/null; fi
STATE="${BROKK_STATE_OVERRIDE:-${STATE:-${YMIR_STATE_DIR:-${YMIR_HOME}/state}}}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
HOST="${HOST:-unknown}"

JDIR="$STATE/journal"
FILE="$JDIR/$HOST.jsonl"

case "${1-}" in
  --list)
    if [ ! -s "$FILE" ]; then printf 'journal[1]{host,pending,namespaces}:\n  "%s",0,"-"\n' "$HOST"; exit 0; fi
    ns_list="$(python3 - "$FILE" <<'PY'
import json, sys
try:
    names = sorted({json.loads(line).get("ns", "") for line in open(sys.argv[1]) if line.strip()})
except Exception:
    names = []
print(",".join(n or "own" for n in names))
PY
)"
    printf 'journal[1]{host,pending,namespaces}:\n'
    printf '  "%s","%s entries","%s"\n' "$HOST" "$(wc -l <"$FILE" | tr -d '[:space:]')" "${ns_list:--}"
    exit 0 ;;
esac

OP=""; DATA=""; ACTOR="${YMIR_ACTOR:-brokk}"; NS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --op) OP="${2-}"; shift 2 ;;
    --data) DATA="${2-}"; shift 2 ;;
    --actor) ACTOR="${2-}"; shift 2 ;;
    --namespace) NS="${2-}"; shift 2 ;;
    *) printf 'error: unknown arg %s\nhelp: journal-append.sh --op <op> [--data <json>] [--actor <who>] [--namespace <ns>]\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$OP" ] || { printf 'error: --op is required\n' >&2; exit 2; }
if [ -n "$NS" ] && ! printf '%s' "$NS" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
  printf 'error: --namespace %s is not a valid namespace (want ^[a-z0-9][a-z0-9-]*$)\n' "$NS" >&2; exit 2
fi

mkdir -p "$JDIR" || { printf 'error: cannot create %s\n' "$JDIR" >&2; exit 1; }

SEQ=$(wc -l <"$FILE" 2>/dev/null | tr -d '[:space:]')
SEQ=$(( ${SEQ:-0} + 1 ))
UUID="$(python3 -c 'import uuid;print(uuid.uuid4().hex)' 2>/dev/null || date -u +%s%N)"
KEY="$HOST:$SEQ:$UUID"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

python3 - "$KEY" "$TS" "$ACTOR" "$OP" "$DATA" "$NS" >>"$FILE" <<'PY'
import json, sys
key, ts, actor, op, data, ns = sys.argv[1:7]
try:
    d = json.loads(data) if data else {}
except Exception:
    d = {"raw": data}
entry = {"key": key, "ts": ts, "actor": actor, "op": op, "data": d}
if ns:
    entry["ns"] = ns
print(json.dumps(entry, ensure_ascii=False))
PY

printf '%s\n' "$KEY"
