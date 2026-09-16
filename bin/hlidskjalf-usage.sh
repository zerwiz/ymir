#!/usr/bin/env bash
# hlidskjalf-usage.sh — what the HARNESSES spent, not just the smithy.
#
# The Statistics gate counted only smithy runs (smidja.db), so a machine burning
# tokens through opencode and pi from morning to night reported "No runs yet". The
# sessions are the usage; this reads them.
#
#   bin/hlidskjalf-usage.sh [--days N]   # JSON, aggregated
#
# SOURCES (verified on this machine):
#   opencode  ~/.local/share/opencode/opencode.db  (SQLite, Drizzle)
#             session / message / part; usage lives in message.data as JSON:
#             {role, modelID, providerID, cost, tokens:{total,input,output,
#              reasoning,cache:{read,write}}}. cost is stored 0 - tokens are truth.
#   pi        ~/.pi/agent/sessions/**/*.jsonl
#
# BOUNDED BY CONSTRUCTION: the db here is 37 GB and holds 132k messages. Nothing
# loads rows into the UI - the aggregation is one SQL statement with json_extract,
# a time window, and a hard row cap, and the result is small by definition.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

DAYS="${YMIR_USAGE_DAYS:-30}"
while [ $# -gt 0 ]; do
  case "$1" in --days) DAYS="${2:-30}"; shift 2 ;; *) shift ;; esac
done

DAYS="$DAYS" python3 - <<'PY'
import json, os, sqlite3, sys, glob
from datetime import datetime, timedelta, timezone

days = int(os.environ.get("DAYS", "30"))
since_ms = int((datetime.now(timezone.utc) - timedelta(days=days)).timestamp() * 1000)
out = {"window_days": days, "sources": {}, "totals": {}, "by_model": []}

oc = os.path.expanduser("~/.local/share/opencode/opencode.db")
if os.path.exists(oc):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % oc, uri=True)
        c.execute("PRAGMA query_only=ON")
        # One statement, aggregated in the engine: never the rows, only the sums.
        rows = c.execute("""
            select coalesce(json_extract(data,'$.modelID'),'unknown') model,
                   count(*) msgs,
                   sum(coalesce(json_extract(data,'$.tokens.input'),0)) input,
                   sum(coalesce(json_extract(data,'$.tokens.output'),0)) output,
                   sum(coalesce(json_extract(data,'$.tokens.cache.read'),0)) cache_read,
                   sum(coalesce(json_extract(data,'$.tokens.cache.write'),0)) cache_write,
                   sum(coalesce(json_extract(data,'$.tokens.reasoning'),0)) reasoning
            from message
            where json_extract(data,'$.tokens') is not null
              and coalesce(json_extract(data,'$.time.created'), 0) >= ?
            group by model order by (sum(coalesce(json_extract(data,'$.tokens.input'),0))
                                   + sum(coalesce(json_extract(data,'$.tokens.output'),0))) desc
            limit 40
        """, (since_ms,)).fetchall()
        rows = [r for r in rows if r[1]]
        out["sources"]["opencode"] = {
            "model": "harness",
            "messages": sum(r[1] for r in rows),
            "input": sum(r[2] for r in rows), "output": sum(r[3] for r in rows),
            "cache_read": sum(r[4] for r in rows), "cache_write": sum(r[5] for r in rows),
            "reasoning": sum(r[6] for r in rows),
        }
        out["by_model"] += [
            {"source": "opencode", "model": r[0], "messages": r[1], "input": r[2],
             "output": r[3], "cache_read": r[4], "cache_write": r[5], "reasoning": r[6]}
            for r in rows
        ]
    except Exception as e:
        out["sources"]["opencode"] = {"error": str(e)[:120]}

# pi keeps TWO stores: the agent home and the older tree beside it. Scanning only
# one under-reported the harness by an order of magnitude (75 messages against 657
# session files), which is how a "small number" masks a missing source.
pi_files = []
for root in ("~/.pi/agent/sessions", "~/.pi/sessions"):
    pi_files += glob.glob(os.path.expanduser(root + "/**/*.jsonl"), recursive=True)
if pi_files:
    agg = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0, "messages": 0}
    models = {}
    for f in pi_files:
        try:
            with open(f, "r", errors="ignore") as fh:
                for line in fh:
                    if '"tokens"' not in line and '"usage"' not in line:
                        continue
                    try:
                        d = json.loads(line)
                    except Exception:
                        continue
                    t = d.get("tokens") or d.get("usage") or {}
                    if not t:
                        continue
                    inp = t.get("input") or t.get("input_tokens") or 0
                    outp = t.get("output") or t.get("output_tokens") or 0
                    cr = (t.get("cache") or {}).get("read") or t.get("cache_read_input_tokens") or 0
                    cw = (t.get("cache") or {}).get("write") or t.get("cache_creation_input_tokens") or 0
                    agg["input"] += inp; agg["output"] += outp
                    agg["cache_read"] += cr; agg["cache_write"] += cw; agg["messages"] += 1
                    m = d.get("modelID") or d.get("model") or "unknown"
                    mm = models.setdefault(m, {"input": 0, "output": 0, "messages": 0})
                    mm["input"] += inp; mm["output"] += outp; mm["messages"] += 1
        except Exception:
            continue
    out["sources"]["pi"] = {"model": "harness", **agg}
    out["by_model"] += [{"source": "pi", "model": k, **v} for k, v in
                        sorted(models.items(), key=lambda kv: -(kv[1]["input"] + kv[1]["output"]))[:20]]

tot = {"messages": 0, "input": 0, "output": 0, "cache_read": 0, "cache_write": 0, "reasoning": 0}
for s in out["sources"].values():
    for k in tot:
        tot[k] += int(s.get(k) or 0)
tot["total"] = tot["input"] + tot["output"]
prompt = tot["input"] + tot["cache_read"]
# local = our own hardware; online = a cloud API. By model id, honestly.
LOCAL_MARKERS = ("llama", "lmstudio", "ollama", "local", "qwen3.6-35b-a3b")
for m in out["by_model"]:
    mid = str(m.get("model", "")).lower()
    m["kind"] = "local" if any(k in mid for k in LOCAL_MARKERS) else "online"

lo = {"local": {"tokens": 0, "calls": 0}, "online": {"tokens": 0, "calls": 0}}
for m in out["by_model"]:
    k = m.get("kind", "online")
    lo[k]["tokens"] += int(m.get("input") or 0) + int(m.get("output") or 0)
    lo[k]["calls"] += int(m.get("messages") or 0)
out["local_online"] = lo

# the gate's section names, filled from the harnesses
oc = out["sources"].get("opencode", {})
pi = out["sources"].get("pi", {})
out["runs"] = {
    "total": int(tot["messages"]), "success": int(tot["messages"]), "fail": 0, "running": 0,
    "success_rate": 100.0 if tot["messages"] else 0.0,
    "tokens": int(tot["input"]) + int(tot["output"]),
    "cost": 0,
    "by_source": {"opencode": int(oc.get("messages") or 0), "pi": int(pi.get("messages") or 0)},
}
out["by_chain"] = [
    {"chain": m.get("source", "harness"), "runs": int(m.get("messages") or 0),
     "tokens": int(m.get("input") or 0) + int(m.get("output") or 0), "cost": 0}
    for m in out["by_model"][:12]
]

tot["cache_hit_ratio"] = round(tot["cache_read"] / prompt, 4) if prompt else 0.0
out["totals"] = tot
print(json.dumps(out))
PY
