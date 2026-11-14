#!/usr/bin/env bash
# hlidskjalf-usage.sh — what EVERY HARNESS spent, and what each number means.
#
# The Statistics gate counted only smithy runs (smidja.db), so a machine burning
# tokens through opencode and pi from morning to night reported "No runs yet". Then it
# read opencode and pi and nothing else, so the Allfather's Claude Code work was
# invisible: *"the stats aren't reading claude."* (plan 275 item 29, 2026-11-14.)
#
#   bin/desktop/hlidskjalf-usage.sh [--days N]   # JSON, aggregated
#
# SOURCES — every harness this machine has, each read from its own store:
#   opencode  ~/.local/share/opencode/opencode.db   (SQLite) message rows + session rows
#   pi        ~/.pi/agent/sessions/**/*.jsonl       one file per session
#   claude    ~/.claude/projects/**/*.jsonl         message.model + message.usage,
#                                                   deduplicated by message.id
#   codex     ~/.codex/sessions/**/rollout-*.jsonl  token_count events; the
#                                                   total_token_usage is CUMULATIVE,
#                                                   so the last one per rollout is the run
#   hermes    <home>/state.db session_model_usage   Bilskirnir's agents and ~/.hermes
#   cursor    ~/.cursor                             probed; no usage store = a named skip
#
# WHAT A NUMBER MEANS (the lies this replaces, all of them on the page 2026-11-14):
#   a RUN is a SESSION or an ERRAND, never a message. `messages` is reported beside it.
#   success/fail are read from the session's own end state, and `unknown` is said out
#   loud rather than counted as a success (61,103 "runs, 100% success" was 61,103
#   messages with no failure ever read).
#   cache read is shown as the provider bills it — summed per call — and the ratio is
#   computed against the prompt it belongs to (`input + cache_read`), never against
#   `input + output`, which is a different quantity (16,478M "against" 310M).
#   COST comes from ONE rule: the harness's recorded cost when it records one, else a
#   published list price, else `null` — never 0. A local model is $0 because the
#   hardware is ours, and that is a fact, not a guess.
#
# BOUNDED BY CONSTRUCTION: the opencode db here is 37 GB and holds 132k messages.
# Nothing loads rows into the UI — the aggregation is SQL in the engine, a time window,
# and a hard row cap, and the result is small by definition.
set -u

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The home is whatever the ONE resolver says (bin/vault/hoard-lib.sh) — never restated
# here (Rule 07). Hermes engine homes live under it, so the path has to be resolved.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_DIR="${YMIR_HOME:-}"
[ -n "$YMIR_HOME_DIR" ] || { command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root YMIR_HOME_DIR; }

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

DAYS="${YMIR_USAGE_DAYS:-30}"
while [ $# -gt 0 ]; do
  case "$1" in --days) DAYS="${2:-30}"; shift 2 ;; *) shift ;; esac
done

DAYS="$DAYS" python3 - <<'PY'
import glob, json, os, sqlite3
from datetime import datetime, timedelta, timezone

days = int(os.environ.get("DAYS", "30"))
now = datetime.now(timezone.utc)
since_dt = now - timedelta(days=days)
since_ms = int(since_dt.timestamp() * 1000)
since_s = int(since_dt.timestamp())

out = {"window_days": days, "sources": {}, "totals": {}, "by_model": []}
# Every row is one (harness, model) pair. The shape is fixed so the UI never guesses.
FIELDS = ("messages", "sessions", "input", "output", "cache_read", "cache_write", "reasoning")

def empty(model, source, provider="", kind="online", agent=""):
    return {"model": model or "unknown", "source": source, "provider": provider,
            "kind": kind, "agent": agent, "cost": None, "cost_source": "none",
            **{k: 0 for k in FIELDS}}

def bump(row, **kw):
    for k, v in kw.items():
        if k in FIELDS:
            row[k] += int(v or 0)
    return row

# --------------------------------------------------------------------------- #
# THE ONE PRICE TABLE. Published list prices per 1M tokens, and only for models
# whose price is published and stable. A model NOT in here is `null`, never 0 —
# an unpriced online call is an unknown cost, not a free one.
# `recorded` always wins: pi and Hermes write their own cost, and that is evidence.
# --------------------------------------------------------------------------- #
PRICES = {
    # Anthropic list prices, per 1M tokens (input, cache read, cache write, output).
    "claude-opus":   (15.0, 1.50, 18.75, 75.0),
    "claude-sonnet": (3.0, 0.30, 3.75, 15.0),
    "claude-haiku":  (0.80, 0.08, 1.0, 4.0),
}

def price_for(model):
    m = (model or "").lower()
    for fam, p in PRICES.items():
        if fam in m:
            return p
    return None

def cost_of(model, kind, inp, outp, cr, cw, recorded):
    """ONE rule for every harness: recorded → published → unknown (None)."""
    if recorded is not None:
        try:
            return float(recorded), "recorded"
        except (TypeError, ValueError):
            pass
    if kind == "local":
        return 0.0, "local"
    p = price_for(model)
    if p:
        pin, pcr, pcw, po = p
        return round((inp * pin + cr * pcr + cw * pcw + outp * po) / 1_000_000, 6), "list"
    return None, "unknown"

# --------------------------------------------------------------------------- #
# opencode — one SQL statement; the engine aggregates 132k rows, we get 40.
# --------------------------------------------------------------------------- #
oc = os.path.expanduser("~/.local/share/opencode/opencode.db")
if os.path.exists(oc):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % oc, uri=True)
        c.execute("PRAGMA query_only=ON")
        rows = c.execute("""
            select coalesce(json_extract(data,'$.providerID'),'opencode') provider,
                   coalesce(json_extract(data,'$.modelID'),'unknown') model,
                   count(distinct session_id) sessions,
                   count(*) msgs,
                   sum(coalesce(json_extract(data,'$.tokens.input'),0)) input,
                   sum(coalesce(json_extract(data,'$.tokens.output'),0)) output,
                   sum(coalesce(json_extract(data,'$.tokens.cache.read'),0)) cache_read,
                   sum(coalesce(json_extract(data,'$.tokens.cache.write'),0)) cache_write,
                   sum(coalesce(json_extract(data,'$.tokens.reasoning'),0)) reasoning
            from message
            where json_extract(data,'$.tokens') is not null
              and coalesce(json_extract(data,'$.time.created'), 0) >= ?
            group by provider, model
            order by (sum(coalesce(json_extract(data,'$.tokens.input'),0))
                    + sum(coalesce(json_extract(data,'$.tokens.output'),0))) desc
            limit 40
        """, (since_ms,)).fetchall()
        src = {k: 0 for k in FIELDS}
        per = []
        for prov, model, sess, msgs, inp, outp, cr, cw, rs in rows:
            r = empty(model, "opencode", provider=prov)
            bump(r, sessions=sess, messages=msgs, input=inp, output=outp,
                 cache_read=cr, cache_write=cw, reasoning=rs)
            per.append(r)
            for k in FIELDS:
                src[k] += r[k]
        out["sources"]["opencode"] = {"ok": True, "model": "harness", **src}
        out["by_model"] += per
    except Exception as e:
        out["sources"]["opencode"] = {"ok": False, "error": str(e)[:120]}

# --------------------------------------------------------------------------- #
# pi — one jsonl per session under two roots ("the agent home and the older tree
# beside it"): scanning only one under-reported the harness by an order of
# magnitude. A session file IS a run.
# --------------------------------------------------------------------------- #
def read_pi():
    files = []
    for root in ("~/.pi/agent/sessions", "~/.pi/sessions"):
        files += glob.glob(os.path.expanduser(root + "/**/*.jsonl"), recursive=True)
    if not files:
        return None, []
    src = {k: 0 for k in FIELDS}
    per = {}
    for f in files:
        try:
            if os.path.getmtime(f) < since_s:
                continue
        except OSError:
            continue
        used_models = set()
        try:
            fh = open(f, "r", errors="ignore")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"tokens"' not in line and '"usage"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                t = d.get("tokens") or d.get("usage") or {}
                msg = d.get("message") if isinstance(d.get("message"), dict) else {}
                if not t and msg:
                    t = msg.get("usage") or {}
                if not t:
                    continue
                inp = t.get("input") or t.get("input_tokens") or 0
                outp = t.get("output") or t.get("output_tokens") or 0
                cr = (t.get("cache") or {}).get("read") or t.get("cacheRead") or t.get("cache_read_input_tokens") or 0
                cw = (t.get("cache") or {}).get("write") or t.get("cacheWrite") or t.get("cache_creation_input_tokens") or 0
                rs = t.get("reasoning") or t.get("reasoning_tokens") or 0
                m = d.get("modelID") or d.get("model") or msg.get("model") or "unknown"
                cc = t.get("cost") or {}
                cost = cc.get("total") if isinstance(cc, dict) else cc
                r = per.get(m) or empty(m, "pi")
                bump(r, messages=1, input=inp, output=outp, cache_read=cr, cache_write=cw, reasoning=rs)
                if cost is not None:
                    try:
                        r["cost"] = round(float(r["cost"] or 0) + float(cost), 6)
                        r["cost_source"] = "recorded"
                    except (TypeError, ValueError):
                        pass
                used_models.add(m)
                per[m] = r
        # one file, one run — counted on the models it actually used
        for m in used_models:
            per[m]["sessions"] += 1
    for r in per.values():
        for k in FIELDS:
            src[k] += r[k]
    return src, list(per.values())

pi_src, pi_rows = read_pi()
if pi_src is not None:
    out["sources"]["pi"] = {"ok": True, "model": "harness", **pi_src}
    out["by_model"] += pi_rows

# --------------------------------------------------------------------------- #
# Claude Code — ~/.claude/projects/<project>/<session>.jsonl. Usage lives at
# message.usage; the same message id appears once per turn, but a resumed or
# compacted session repeats it, so rows are DEDUPLICATED BY message.id.
# --------------------------------------------------------------------------- #
def read_claude():
    files = glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"), recursive=True)
    if not files:
        return None, []
    src = {k: 0 for k in FIELDS}
    per = {}
    seen_ids = set()
    for f in files:
        try:
            if os.path.getmtime(f) < since_s:
                continue
        except OSError:
            continue
        used = set()
        try:
            fh = open(f, "r", errors="ignore")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                msg = d.get("message") if isinstance(d.get("message"), dict) else None
                if not msg:
                    continue
                u = msg.get("usage") or {}
                if not u:
                    continue
                mid = msg.get("id") or d.get("uuid") or ""
                if mid and mid in seen_ids:
                    continue
                if mid:
                    seen_ids.add(mid)
                m = msg.get("model") or "claude"
                inp = u.get("input_tokens") or 0
                outp = u.get("output_tokens") or 0
                cr = u.get("cache_read_input_tokens") or 0
                cw = u.get("cache_creation_input_tokens") or 0
                rs = ((u.get("output_tokens_details") or {}).get("thinking_tokens")) or 0
                r = per.get(m) or empty(m, "claude", provider="anthropic")
                bump(r, messages=1, input=inp, output=outp, cache_read=cr, cache_write=cw, reasoning=rs)
                used.add(m)
                per[m] = r
        for m in used:
            per[m]["sessions"] += 1
    for r in per.values():
        for k in FIELDS:
            src[k] += r[k]
    return src, list(per.values())

cl_src, cl_rows = read_claude()
if cl_src is not None:
    out["sources"]["claude"] = {"ok": True, "model": "harness", **cl_src}
    out["by_model"] += cl_rows

# --------------------------------------------------------------------------- #
# Codex — ~/.codex/sessions/<y>/<m>/<d>/rollout-*.jsonl. `token_count` carries
# `total_token_usage`, which is CUMULATIVE for the rollout: summing the events
# would multiply the truth by the number of turns, so the LAST one per file is
# the run's total.
# --------------------------------------------------------------------------- #
def read_codex():
    files = glob.glob(os.path.expanduser("~/.codex/sessions/**/rollout-*.jsonl"), recursive=True)
    if not files:
        return None, []
    src = {k: 0 for k in FIELDS}
    per = {}
    for f in files:
        try:
            if os.path.getmtime(f) < since_s:
                continue
        except OSError:
            continue
        model = "codex"
        last = None
        turns = 0
        try:
            fh = open(f, "r", errors="ignore")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"model"' not in line and 'token_count' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if d.get("type") == "turn_context":
                    model = ((d.get("payload") or {}).get("model")) or model
                p = d.get("payload") or {}
                if p.get("type") == "token_count":
                    turns += 1
                    info = p.get("info") or {}
                    if info.get("total_token_usage"):
                        last = info["total_token_usage"]
        if not last:
            continue
        r = per.get(model) or empty(model, "codex", provider="openai")
        bump(r,
             messages=turns, sessions=1,
             input=last.get("input_tokens") or 0,
             output=last.get("output_tokens") or 0,
             cache_read=last.get("cached_input_tokens") or 0,
             cache_write=last.get("cache_write_input_tokens") or 0,
             reasoning=last.get("reasoning_output_tokens") or 0)
        per[model] = r
    for r in per.values():
        for k in FIELDS:
            src[k] += r[k]
    return src, list(per.values())

cx_src, cx_rows = read_codex()
if cx_src is not None:
    out["sources"]["codex"] = {"ok": True, "model": "harness", **cx_src}
    out["by_model"] += cx_rows

# --------------------------------------------------------------------------- #
# Hermes — Bilskirnir's agents and the operator's own home. `session_model_usage`
# is already the per-session, per-model aggregate, and it records its own cost.
# --------------------------------------------------------------------------- #
def read_hermes():
    homes = [os.path.expanduser("~/.hermes")]
    home_root = os.environ.get("YMIR_HOME_DIR", "")
    if home_root:
        homes += glob.glob(os.path.join(home_root, "bilskirnir/data/engines/*"))
    src = {k: 0 for k in FIELDS}
    per = {}
    found = []
    seen = set()
    for home in homes:
        db = os.path.join(home, "state.db")
        real = os.path.realpath(db)
        if not os.path.exists(db) or real in seen:
            continue
        seen.add(real)
        try:
            c = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
            c.execute("PRAGMA query_only=ON")
            rows = c.execute("""
                select model, billing_base_url, count(distinct session_id) sessions,
                       sum(api_call_count) calls,
                       sum(input_tokens) input, sum(output_tokens) output,
                       sum(cache_read_tokens) cache_read, sum(cache_write_tokens) cache_write,
                       sum(reasoning_tokens) reasoning,
                       sum(coalesce(actual_cost_usd, estimated_cost_usd)) cost
                from session_model_usage
                where coalesce(last_seen, 0) >= ?
                group by model, billing_base_url
            """, (since_s,)).fetchall()
        except Exception:
            continue
        found.append(os.path.basename(home.rstrip("/")) or "hermes")
        for model, base, sess, calls, inp, outp, cr, cw, rs, cost in rows:
            r = per.get(model) or empty(model, "hermes", provider=(base or "").split("//")[-1].split("/")[0])
            bump(r, sessions=sess, messages=calls or 0, input=inp, output=outp,
                 cache_read=cr, cache_write=cw, reasoning=rs)
            if cost:
                r["cost"] = round(float(r["cost"] or 0) + float(cost), 6)
                r["cost_source"] = "recorded"
            per[model] = r
    if not found:
        return None, [], []
    for r in per.values():
        for k in FIELDS:
            src[k] += r[k]
    return src, list(per.values()), found

he_res = read_hermes()
if he_res[0] is not None:
    he_src, he_rows, he_homes = he_res
    out["sources"]["hermes"] = {"ok": True, "model": "harness", "homes": he_homes, **he_src}
    out["by_model"] += he_rows

# --------------------------------------------------------------------------- #
# Cursor — probed, never assumed. ~/.cursor holds settings today and no usage
# store; the skip says so instead of silently reporting zero.
# --------------------------------------------------------------------------- #
cur = os.path.expanduser("~/.cursor")
if os.path.isdir(cur):
    stores = glob.glob(os.path.join(cur, "**", "usage*.json"), recursive=True)
    out["sources"]["cursor"] = {
        "ok": False,
        "skip": "no usage store found under ~/.cursor" if not stores else "usage store present but unread",
    }

# --------------------------------------------------------------------------- #
# LOCAL vs ONLINE — by WHERE the model ran, not by which harness ran it.
# The registry is the truth: a model served by llama-swap or a llama.cpp seat is
# OUR hardware whatever its id sounds like. (245M tokens of pi work was once
# reported "online" because `deepseek-v4.1-flash` matched no marker.)
# --------------------------------------------------------------------------- #
LOCAL_MODELS, LOCAL_PROVIDERS = set(), set()
try:
    reg = json.load(open(os.path.expanduser("~/.pi/agent/models.json")))
    for provider, spec in (reg.get("providers") or {}).items():
        if not isinstance(spec, dict):
            continue
        if any(k in provider.lower() for k in ("llama", "local", "ollama", "lmstudio")):
            LOCAL_PROVIDERS.add(provider)
            ms = spec.get("models") or []
            for e in (ms if isinstance(ms, list) else list(ms.keys())):
                name = (e.get("id") or e.get("name")) if isinstance(e, dict) else e
                if name:
                    LOCAL_MODELS.add(str(name))
                    if str(name).endswith("-fast"):
                        LOCAL_MODELS.add(str(name)[:-5])
except Exception:
    pass

for m in out["by_model"]:
    mid = str(m.get("model", ""))
    prov = str(m.get("provider", "")).lower()
    if m.get("source") == "hermes" and prov in ("", "nous"):
        m["kind"] = "online"
    elif mid in LOCAL_MODELS or prov in LOCAL_PROVIDERS or any(
            k in mid.lower() for k in ("llama", "lmstudio", "ollama")):
        m["kind"] = "local"
    else:
        m["kind"] = "online"
    # the cost rule, applied once, on the final row
    cost, src = cost_of(mid, m["kind"], m["input"], m["output"],
                        m["cache_read"], m["cache_write"], m.get("cost"))
    m["cost"] = cost
    m["cost_source"] = src
    # the agent column: the HARNESS is what the row is, and it is never "—"
    m["harness"] = m.get("source", "")
    m["agent"] = m.get("agent") or m.get("source", "")

out["by_model"].sort(key=lambda r: -(r["input"] + r["output"]))

# --------------------------------------------------------------------------- #
# THE TOTALS — one set of numbers, computed once, used everywhere.
# --------------------------------------------------------------------------- #
tot = {k: 0 for k in FIELDS}
tot.update({"cost": 0.0, "cost_unknown_calls": 0})
for r in out["by_model"]:
    for k in FIELDS:
        tot[k] += int(r.get(k) or 0)
    if r.get("cost") is None:
        tot["cost_unknown_calls"] += int(r.get("messages") or 0)
    else:
        tot["cost"] = round(tot["cost"] + float(r["cost"]), 6)

# A bucket where NOTHING is priced is `unknown`, not $0.00 — that $0.00 was the lie.
if tot["cost_unknown_calls"] >= tot["messages"] and tot["messages"]:
    tot["cost"] = None
tot["total"] = tot["input"] + tot["output"]
tot["prompt"] = tot["input"] + tot["cache_read"]          # what was actually sent
tot["cache_hit_ratio"] = round(tot["cache_read"] / tot["prompt"], 4) if tot["prompt"] else 0.0
out["totals"] = tot

lo = {"local": dict({"tokens": 0, "calls": 0, "sessions": 0, "input": 0, "output": 0,
                     "cache_read": 0, "cost": 0.0}, **{}),
      "online": {}}
lo["online"] = {"tokens": 0, "calls": 0, "sessions": 0, "input": 0, "output": 0,
                "cache_read": 0, "cost": 0.0}
for m in out["by_model"]:
    k = m["kind"]
    lo[k]["tokens"] += m["input"] + m["output"]
    lo[k]["calls"] += m["messages"]          # calls ARE messages: a call is one exchange
    lo[k]["sessions"] += m["sessions"]       # and sessions are RUNS — a different number
    lo[k]["input"] += m["input"]
    lo[k]["output"] += m["output"]
    lo[k]["cache_read"] += m["cache_read"]
    if m.get("cost") is not None:
        lo[k]["cost"] = round(lo[k]["cost"] + float(m["cost"]), 6)
out["local_online"] = lo

# A RUN is a SESSION. Failure is read where a harness states one; where it does not,
# `unknown` is said rather than counted as a success.
sessions = tot["sessions"]
out["runs"] = {
    "total": sessions,
    "messages": tot["messages"],
    "success": None,          # no harness writes a per-session terminal state we can trust
    "fail": None,
    "unknown": sessions,
    "success_rate": None,     # never invented; the UI says "not recorded"
    "tokens": tot["total"],
    "cost": tot["cost"],
    "cost_unknown_calls": tot["cost_unknown_calls"],
    "by_source": {k: int((v or {}).get("sessions") or 0)
                  for k, v in out["sources"].items() if (v or {}).get("ok")},
}

# BY HARNESS (what `by_chain` was mislabelled as) and BY MODEL (what `by_workflow` was).
by_harness = {}
for m in out["by_model"]:
    h = by_harness.setdefault(m["source"], {"source": m["source"], "runs": 0, "messages": 0,
                                            "tokens": 0, "cost": 0.0, "cost_unknown": 0})
    h["runs"] += m["sessions"]
    h["messages"] += m["messages"]
    h["tokens"] += m["input"] + m["output"]
    if m.get("cost") is None:
        h["cost_unknown"] += m["messages"]
    else:
        h["cost"] = round(h["cost"] + float(m["cost"]), 6)
for h in by_harness.values():
    if h["cost_unknown"] >= h["messages"] and h["messages"]:
        h["cost"] = None
out["by_chain"] = sorted(by_harness.values(), key=lambda r: -r["tokens"])
out["by_harness"] = out["by_chain"]
out["by_workflow"] = [
    {"workflow": m["model"], "source": m["source"], "runs": m["sessions"],
     "messages": m["messages"], "tokens": m["input"] + m["output"],
     "cost": m["cost"], "kind": m["kind"], "agent": m["agent"]}
    for m in out["by_model"][:25]
]

# THE GATE'S OWN NAMES, filled from every harness — the page reads this block.
out["gate"] = {
    "totals": {
        "runs": sessions,
        "messages": tot["messages"],
        "success": None,
        "fail": None,
        "running": 0,
        "tokens": tot["total"],
        "cost": tot["cost"],
        "cost_unknown_calls": tot["cost_unknown_calls"],
    },
    "usage": {
        "input": tot["input"],
        "output": tot["output"],
        "cache_read": tot["cache_read"],
        "cache_write": tot["cache_write"],
        "total": tot["total"],
        "prompt": tot["prompt"],
        "cache_hit_ratio": tot["cache_hit_ratio"],
    },
    "providers": {
        "local": lo["local"],
        "online": lo["online"],
        "per_model": [
            {"model": m["model"], "agent": m["agent"], "harness": m["harness"],
             "provider": m["provider"], "kind": m["kind"],
             "events": m["messages"], "sessions": m["sessions"],
             "tokens": m["input"] + m["output"], "cost": m["cost"],
             "cost_source": m["cost_source"]}
            for m in out["by_model"]
        ],
    },
    "by_chain": out["by_chain"],
    "by_harness": out["by_chain"],
    "by_model": out["by_workflow"],
}

print(json.dumps(out))
PY
