#!/usr/bin/env bash
# smidja-observe.sh — the smithy's trace, read-only (W0075). Reads the REPO's own
# smidja.db (SQLite, WAL) at `smidja/smidja_data/smidja.db` — never any external
# repo. If no db is present it says so plainly. Galdr-style TOON.
#
# Usage:
#   smidja-observe.sh health
#   smidja-observe.sh sessions [--limit N]
#   smidja-observe.sh session <id>
#   smidja-observe.sh decisions
#   smidja-observe.sh stats
#   smidja-observe.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_DB="${SMIDJA_DB:-$ROOT/smidja/smidja_data/smidja.db}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CMD="${1-}"; shift || true
DB="$DEFAULT_DB"; LIMIT=50; ARG=""
while [ $# -gt 0 ]; do case "$1" in --db) DB=${2-}; shift 2 ;; --limit) LIMIT=${2-50}; shift 2 ;; *) ARG=$1; shift ;; esac; done

if [ ! -f "$DB" ]; then
  printf 'smidja[1]{field,value}:\n'
  printf '  "db","%s"\n' "${DB#"$ROOT"/}"
  printf '  "status","absent (run a smidja factory to write the trace)"\n'
  exit 0
fi

python3 - "$DB" "$CMD" "$ARG" "$LIMIT" <<'PY'
import sqlite3, sys, json
db, cmd, arg, limit = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
cur = con.cursor()
def tbl(q, args=()):
    try: return [dict(r) for r in cur.execute(q, args).fetchall()]
    except Exception: return []
def col(table, name, default="NULL"):
    try:
        cur.execute(f"select {name} from {table} limit 0"); return name
    except Exception: return default

if cmd == "health":
    n = (tbl("select count(*) c from sessions") or [{"c":0}])[0]["c"]
    print('smidja[1]{db,sessions,journal}:')
    print(f'  "{db}",{n},"ro"')
elif cmd == "sessions":
    rows = tbl("select smidja_id, smidja_name, status, engineer, total_tokens, total_cost, started_at, ended_at from sessions order by started_at desc limit ?", (limit,))
    print(f'sessions[{len(rows)}]{{smidja_id,name,status,engineer,tokens,cost,started_at}}:')
    for r in rows:
        print('  "%s","%s","%s","%s",%s,%s,"%s"' % (r.get("smidja_id",""), (r.get("smidja_name") or "").replace('"',"'"), r.get("status") or "", r.get("engineer") or "", r.get("total_tokens") or 0, r.get("total_cost") or 0, r.get("started_at") or ""))
elif cmd == "session":
    if not arg:
        print('error: session needs an id'); sys.exit(2)
    ph = tbl("select seq,name,kind,owner,status,attempt,error,started_at,ended_at from phases where smidja_id=? order by seq,rowid", (arg,))
    ag = tbl("select agent,coding_agent,model,context_tokens,context_window from agent_sessions where smidja_id=? order by created_at,agent", (arg,))
    print(f'phases[{len(ph)}]{{seq,name,kind,owner,status,attempt,error}}:')
    for r in ph:
        print('  %s,"%s","%s","%s","%s",%s,"%s"' % (r.get("seq") or 0, (r.get("name") or "").replace('"',"'"), r.get("kind") or "", r.get("owner") or "", r.get("status") or "", r.get("attempt") or 0, (r.get("error") or "").replace('"',"'")[:80]))
    print(f'agents[{len(ag)}]{{agent,coding_agent,model,context_tokens,context_window}}:')
    for r in ag:
        print('  "%s","%s","%s",%s,%s' % (r.get("agent",""), r.get("coding_agent") or "", r.get("model") or "", r.get("context_tokens") or 0, r.get("context_window") or 0))
elif cmd == "decisions":
    rows = tbl("select ph.name phase, ph.error, ag.model, count(*) c from phases ph left join agent_sessions ag on ag.smidja_id=ph.smidja_id and ag.agent=ph.owner where ph.status='fail' group by ph.name, ph.error, ag.model order by c desc")
    print(f'decisions[{len(rows)}]{{phase,model,count,error}}:')
    for r in rows:
        print('  "%s","%s",%s,"%s"' % ((r.get("phase") or "").replace('"',"'"), r.get("model") or "", r.get("c",0), (r.get("error") or "").replace('"',"'")[:100]))
elif cmd == "stats":
    s = (tbl("select count(*) runs, coalesce(sum(total_tokens),0) tokens, coalesce(sum(total_cost),0) cost from sessions") or [{}])[0]
    by_chain = tbl("select coalesce(smidja_name,'?') chain, count(*) c from sessions group by smidja_name order by c desc")
    by_model = tbl("select model, count(*) c from agent_sessions group by model order by c desc")
    print('stats[1]{runs,tokens,cost}:')
    print('  %s,%s,%s' % (s.get("runs",0), s.get("tokens",0), s.get("cost",0)))
    print(f'by_chain[{len(by_chain)}]{{chain,runs}}:')
    for r in by_chain: print('  "%s",%s' % ((r.get("chain") or "").replace('"',"'"), r.get("c",0)))
    print(f'by_model[{len(by_model)}]{{model,runs}}:')
    for r in by_model: print('  "%s",%s' % (r.get("model") or "", r.get("c",0)))
else:
    print(f'error: unknown command {cmd}'); sys.exit(2)
PY
