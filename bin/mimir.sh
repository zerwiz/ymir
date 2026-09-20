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

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
WELL="${YMIR_MEMORY_DIR:-$YMIR_HOME/memory/well}/episodes.jsonl"
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
    K=5; MODE=hybrid
    while [ $# -gt 0 ]; do case "$1" in --k) K=${2-5}; shift 2 ;; --mode) MODE=${2-hybrid}; shift 2 ;; *) shift ;; esac; done
    [ -n "$Q" ] || { printf 'error: recall needs a query\nhelp: bin/mimir.sh recall "<query>"\n' >&2; exit 2; }
    if bridge_up; then
      out=$(curl -fsS --max-time 5 "$BRIDGE/recall?q=$(printf '%s' "$Q" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))')&k=$K&mode=$MODE" 2>/dev/null)
      [ -n "$out" ] && { printf '%s\n' "$out" | python3 -c 'import json,sys
d=json.load(sys.stdin)
rs=d.get("results",d if isinstance(d,list) else [])
print(f"recall[{len(rs)}]{{score,source,title}}:")
for r in rs[:20]:
    e=r.get("episode",r); sc=r.get("score",0)
    t=(e.get("content","").split("\n")[0] or "")[:90]
    print(f"  {sc},{(e.get(\"agents\") or [\"well\"])[0]},{t}")' 2>/dev/null && exit 0; }
    fi
    # local fallback: substring search over the well
    python3 - "$WELL" "$Q" "$K" <<'PY'
import json,sys
well,q,k=sys.argv[1],sys.argv[2].lower(),int(sys.argv[3])
rows=[]
for line in open(well, encoding='utf-8', errors='ignore'):
    if not line.strip().startswith('{'): continue
    try: e=json.loads(line)
    except: continue
    c=e.get('content','')
    if q in c.lower(): rows.append((e,c))
print(f"recall[{min(len(rows),k)}]{{score,source,title}}:")
for e,c in rows[-k:][::-1]:
    t=(c.split('\n')[0] or '').replace('#','').strip()[:90]
    print(f"  0.5,\"{e.get('source','well')}\",\"{t}\"")
PY
    ;;

  observe)
    TEXT="${1-}"; shift || true
    TAGS="runtime"; SRC="brokk"
    while [ $# -gt 0 ]; do case "$1" in --tags) TAGS=${2-}; shift 2 ;; --source) SRC=${2-}; shift 2 ;; *) shift ;; esac; done
    [ -n "$TEXT" ] || { printf 'error: observe needs text\nhelp: bin/mimir.sh observe "<text>"\n' >&2; exit 2; }
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
    printf 'error: unknown command %s\nhelp: bin/mimir.sh [health|recall|observe|timeline|--version]\n' "$CMD" >&2
    exit 2 ;;
esac
