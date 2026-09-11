#!/usr/bin/env bash
# workspace-rag.sh — memory over the realm workspaces (W0038).
#
# Hybrid recall across `workspace/` and `svartalfaheim/<realm>/workspace/*`: index
# Markdown into the well, query by term overlap, and expose an entity graph from
# `workspace/memory/entity_graph/`. Local, deterministic, no network. Galdr TOON.
#
# Usage:
#   workspace-rag.sh index [--realm <realm>]
#   workspace-rag.sh query <terms...> [--k N]
#   workspace-rag.sh entities
#   workspace-rag.sh graph [--entity X]
#   workspace-rag.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STORE="$ROOT/.agents/memory/well/workspace.jsonl"
REALM_FILE="$ROOT/data/realm.md"
DEFAULT_REALM="$(head -n1 "$REALM_FILE" 2>/dev/null | tr -d '[:space:]')"
DEFAULT_REALM="${DEFAULT_REALM:-way-of}"

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac
[ -e "$STORE" ] || { mkdir -p "$(dirname "$STORE")"; : >"$STORE"; }

index_cmd() {
  local realm=$DEFAULT_REALM
  while [ $# -gt 0 ]; do case "$1" in --realm) realm=${2-}; shift 2 ;; *) shift ;; esac; done
  local n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    add=$(python3 - "$f" "$ROOT" "$realm" "$STORE" <<'PY'
import sys, os, re, json, hashlib, datetime
f, root, realm, store = sys.argv[1:5]
try: text=open(f, encoding='utf-8', errors='ignore').read()
except: sys.exit(0)
rel=os.path.relpath(f, root)
seen=set()
try:
    for line in open(store, encoding='utf-8', errors='ignore'):
        try: seen.add(json.loads(line).get('hash'))
        except: pass
except FileNotFoundError: pass
# chunk by heading
chunks=[]; head=''; buf=[]
def flush():
    if buf:
        body='\n'.join(buf).strip()
        if body: chunks.append((head,body))
for line in text.split('\n'):
    if line.startswith('#'):
        flush(); head=line.lstrip('# ').strip(); buf=[]
    else: buf.append(line)
flush()
added=0
with open(store,'a',encoding='utf-8') as out:
    for head,body in chunks:
        content=(head+'\n'+body).strip()
        if len(content)<40: continue
        h=hashlib.sha256(content.encode()).hexdigest()
        if h in seen: continue
        seen.add(h)
        rec={'timestamp':datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
             'source':rel,'tags':['workspace',realm],'content':content[:2000],'hash':h}
        out.write(json.dumps(rec)+'\n'); added+=1
print(added)
PY
)
    add=${add:-0}
    n=$((n + add))
  done < <(find "$ROOT/workspace" "$ROOT/svartalfaheim/$realm/workspace" "$ROOT/midgard" -name '*.md' 2>/dev/null | sort)
  printf 'indexed[1]{realm,store,added,entries}:\n  "%s","%s",%s,%s\n' "$realm" "${STORE#"$ROOT"/}" "$n" "$(wc -l <"$STORE" | tr -d ' ')"
}

query_cmd() {
  local k=5 terms=""
  while [ $# -gt 0 ]; do case "$1" in --k) k=${2-5}; shift 2 ;; *) terms="$terms $1"; shift ;; esac; done
  terms=$(printf '%s' "$terms" | sed 's/^ *//')
  [ -n "$terms" ] || { printf 'error: query needs terms\n' >&2; exit 2; }
  python3 - "$STORE" "$terms" "$k" <<'PY'
import json,sys,re
store,terms,k=sys.argv[1],sys.argv[2].lower(),int(sys.argv[3])
words=[w for w in re.split(r'\W+',terms) if len(w)>2] or [terms]
rows=[]
for line in open(store, encoding='utf-8', errors='ignore'):
    try: e=json.loads(line)
    except: continue
    c=e.get('content','').lower()
    score=sum(c.count(w) for w in words)
    if score>0: rows.append((score,e))
rows.sort(key=lambda r:-r[0])
print(f"recall[{min(len(rows),k)}]{{score,source,title}}:")
for sc,e in rows[:k]:
    t=(e.get('content','').split('\n')[0] or '').replace('#','').strip()[:90]
    print(f"  {sc},\"{e.get('source','workspace')}\",\"{t}\"")
PY
}

entity_files() { find "$ROOT/workspace" "$ROOT/svartalfaheim/$DEFAULT_REALM/workspace" -path '*/entity_graph/*' -name '*.md' 2>/dev/null; }

entities_cmd() {
  printf 'entities[%s]{entity,source}:\n' "$(entity_files | xargs -r -I{} sh -c "grep -ohE '\[\[[^]]+\]\]' '{}' 2>/dev/null" | sed 's/\[\[//;s/\]\]//' | sort -u | wc -l | tr -d ' ')"
  entity_files | xargs -r -I{} sh -c "grep -ohE '\[\[[^]]+\]\]' '{}' 2>/dev/null" | sed 's/\[\[//;s/\]\]//' | sort -u | while read -r e; do [ -n "$e" ] && printf '  "%s","entity_graph"\n' "$e"; done
}

graph_cmd() {
  local ent=""; while [ $# -gt 0 ]; do case "$1" in --entity) ent=${2-}; shift 2 ;; *) shift ;; esac; done
  printf 'graph[%s]{from,to}:\n' "$(entity_files | xargs -r -I{} sh -c "grep -ohE '\[\[[^]]+\]\] *[-=]> *\[\[[^]]+\]\]' '{}' 2>/dev/null" | wc -l | tr -d ' ')"
  entity_files | xargs -r -I{} sh -c "grep -ohE '\[\[[^]]+\]\] *[-=]> *\[\[[^]]+\]\]' '{}' 2>/dev/null" | while IFS= read -r line; do
    from=$(printf '%s' "$line" | sed -E 's/\[\[([^]]+)\]\].*/\1/')
    to=$(printf '%s' "$line" | sed -E 's/.*\[\[([^]]+)\]\]/\1/')
    [ -n "$ent" ] && { [ "$from" = "$ent" ] || [ "$to" = "$ent" ] || continue; }
    printf '  "%s","%s"\n' "$from" "$to"
  done
}

case "$CMD" in
  index) index_cmd "$@" ;;
  query|recall) query_cmd "$@" ;;
  entities) entities_cmd ;;
  graph) graph_cmd "$@" ;;
  *) printf 'error: unknown command %s\nhelp: bin/workspace-rag.sh [index|query|entities|graph|--version]\n' "$CMD" >&2; exit 2 ;;
esac
