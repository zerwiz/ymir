#!/usr/bin/env bash
# mimir.sh — the well (Mimirsbrunn). Drink before you act, water it after.
#
# Talks to Kaia's engram bridge (:4602) when it is up; otherwise operates the
# local well store (`.agents/memory/well/episodes.jsonl`). Galdr-style TOON.
#
# Usage:
#   mimir.sh health
#   mimir.sh recall <query> [--k N] [--mode hybrid|cosine|spreading]
#   mimir.sh observe <text> [--tags a,b] [--source S]
#   mimir.sh timeline [--entity X]
#   mimir.sh --version
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
YMIR_HOME="${YMIR_HOME}"
# The well log lives INSIDE the hoard, which is `$YMIR_HOME/hodd/` (Rule 04) — this
# line omitted the `hodd/` segment, so recall and observe pointed at a path that has
# never existed. Found by the ymirhome door calling it, not by reading it.
WELL="${YMIR_MEMORY_DIR:-$YMIR_HOME/hodd/memory/well}/episodes.jsonl"
BRIDGE="${MIMIRSBRUNN_URL:-http://127.0.0.1:4602}"

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac
[ -e "$WELL" ] || : >"$WELL"

bridge_up() { command -v curl >/dev/null 2>&1 && curl -fsS --max-time 2 "$BRIDGE/health" >/dev/null 2>&1; }
well_count() { wc -l <"$WELL" | tr -d ' '; }

case "$CMD" in
  health)
    if bridge_up; then
      printf 'well[1]{state,entries,bridge}:\n  "WARM",%s,"online"\n' "$(well_count)"
    else
      printf 'well[1]{state,entries,bridge}:\n  "COLD",%s,"offline"\n' "$(well_count)"
    fi
    ;;

  recall)
    Q="${1-}"; shift || true
    K=5; MODE=hybrid; TAG=""; ACTOR=""; SINCE=""
    # A FILTER THE DOOR DOES NOT IMPLEMENT IS REFUSED, NEVER IGNORED. Until today
    # `recall … --tags domain:snotra` was accepted and silently dropped, so a keeper
    # asking for its own memory was handed the whole house's episodes and told the
    # answer was scoped (measured 2026-10-24; plan 129 §21, the well's three gaps).
    while [ $# -gt 0 ]; do
      case "$1" in
        --k) K=${2-5}; shift 2 ;;
        --mode) MODE=${2-hybrid}; shift 2 ;;
        --tag|--tags) TAG=${2-}; shift 2 ;;
        --actor) ACTOR=${2-}; shift 2 ;;
        --since) SINCE=${2-}; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'error: unknown flag %s\nhelp: recall <query> [--k N] [--mode hybrid|cosine|spreading] [--tag T] [--actor A] [--since YYYY-MM-DD]\n' "$1" >&2; exit 2 ;;
      esac
    done
    [ -n "$Q" ] || { printf 'error: recall needs a query\nhelp: bin/records/mimir.sh recall "<query>"\n' >&2; exit 2; }

    # ONE printer for both paths, so a filtered row looks the same whichever door found it.
    _recall_print() {  # <json-or-empty> <localhost|bridge>
      TAG="$TAG" ACTOR="$ACTOR" SINCE="$SINCE" WHERE="$2" python3 - "$WELL" "$Q" "$K" "$1" <<'PYR'
import json, os, sys
well, q, k, payload = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
tag, actor, since = os.environ.get("TAG",""), os.environ.get("ACTOR",""), os.environ.get("SINCE","")

def keep(e):
    if tag and not any(tag in (t or "") for t in (e.get("tags") or [])): return False
    if actor and actor not in (e.get("agents") or []) and e.get("source","") != actor: return False
    if since and str(e.get("timestamp",""))[:10] < since: return False
    return True

rows = []
if payload.strip():
    try:
        d = json.loads(payload)
    except Exception:
        d = []
    rs = d.get("results", d if isinstance(d, list) else [])
    for r in rs:
        e = r.get("episode", r)
        if keep(e): rows.append((r.get("score", 0), e))
if not rows:
    # THE BRIDGE'S ANSWER IS NOT THE STORE. An episode written seconds earlier is in
    # the file (grep proves it) and absent from the semantic index, so an empty bridge
    # answer must fall through to the store — otherwise "nothing recorded" and "not
    # indexed yet" become the same lie to a keeper.
    for line in open(well, encoding="utf-8", errors="ignore"):
        if not line.strip().startswith("{"): continue
        try: e = json.loads(line)
        except Exception: continue
        if q.lower() in e.get("content","").lower() and keep(e): rows.append((0.5, e))
    rows = rows[-k:]
print(f"recall[{len(rows)}]{{score,source,title}}:")
for sc, e in rows[::-1]:
    t = (e.get("content","").split("\n")[0] or "").replace('"', "").strip()[:90]
    src = (e.get("agents") or [e.get("source","well")])[0] if isinstance(e.get("agents"), list) else e.get("source","well")
    print(f'  {sc},"{src}","{t}"')
PYR
    }

    out=""
    bridge_up && out=$(curl -fsS --max-time 5 "$BRIDGE/recall?q=$(printf '%s' "$Q" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))')&k=$K&mode=$MODE" 2>/dev/null) || out=""
    _recall_print "$out" bridge
    exit 0
    ;;
  observe)
    TEXT="${1-}"; shift || true
    TAGS="runtime"; SRC="brokk"
    while [ $# -gt 0 ]; do case "$1" in --tags) TAGS=${2-}; shift 2 ;; --source) SRC=${2-}; shift 2 ;; *) shift ;; esac; done
    [ -n "$TEXT" ] || { printf 'error: observe needs text\nhelp: bin/records/mimir.sh observe "<text>"\n' >&2; exit 2; }
    json=$(printf '%s' "$TEXT" | python3 -c 'import json,sys,hashlib,datetime
t=sys.stdin.read()
print(json.dumps({"timestamp":datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),"source":"'"$SRC"'","tags":"'"$TAGS"'".split(","),"content":t,"hash":hashlib.sha256(t.encode()).hexdigest()}))')
    printf '%s\n' "$json" >>"$WELL"
    if bridge_up; then curl -fsS --max-time 3 -X POST -H 'content-type: application/json' -d "$json" "$BRIDGE/observe" >/dev/null 2>&1 || true; fi
    printf 'observed[1]{source,tags,bridge}:\n  "%s","%s","%s"\n' "$SRC" "$TAGS" "$(bridge_up && echo online || echo local)"
    ;;

  timeline)
    ENTITY=""; while [ $# -gt 0 ]; do case "$1" in --entity) ENTITY=${2-}; shift 2 ;; *) shift ;; esac; done
    if bridge_up && [ -n "$ENTITY" ]; then
      curl -fsS --max-time 5 "$BRIDGE/timeline?entity=$(printf '%s' "$ENTITY" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))')" 2>/dev/null && exit 0
    fi
    python3 - "$WELL" <<'PY'
import json,sys
rows=[]
for line in open(sys.argv[1], encoding='utf-8', errors='ignore'):
    if not line.strip().startswith('{'): continue
    try: e=json.loads(line)
    except: continue
    rows.append(e)
print(f"timeline[{min(len(rows),20)}]{{ts,source,title}}:")
for e in rows[-20:][::-1]:
    t=(e.get('content','').split('\n')[0] or '').replace('#','').strip()[:80]
    print(f"  \"{e.get('timestamp','')}\",\"{e.get('source','well')}\",\"{t}\"")
PY
    ;;

  *)
    printf 'error: unknown command %s\nhelp: bin/records/mimir.sh [health|recall|observe|timeline|--version]\n' "$CMD" >&2
    exit 2 ;;
esac
