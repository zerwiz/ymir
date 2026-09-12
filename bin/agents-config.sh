#!/usr/bin/env bash
# agents-config.sh — one YAML for the Allfather's agent/harness/model combination.
#
#   bin/agents-config.sh show                 # the current combination (TOON)
#   bin/agents-config.sh get <agent> <key>    # key: harness | model
#   bin/agents-config.sh resolve              # exact ids for local provider models
#   bin/agents-config.sh init                 # seed config/agents.yaml from the template
#   bin/agents-config.sh apply                # write it into agents + project config
#   bin/agents-config.sh --version
#
# Source of truth: config/agents.yaml. `apply` sets `model:` in the canonical
# `.agents/agents/*.md` (matched by `name:`), writes local providers + agent
# models into project `opencode.json`, emits a runnable primary for any agent
# marked `primary: true`, and caches the resolved combination in
# `state/agents-resolved.json` (read by `get` and bin/agent-run.sh).
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG="${YMIR_AGENTS_YAML:-$ROOT/config/agents.yaml}"
RESOLVED="$ROOT/state/agents-resolved.json"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-show}"; shift || true

# init — seed the private setup from the tracked template (idempotent).
if [ "$ACTION" = init ]; then
  if [ -r "$CFG" ]; then
    printf 'agents-config[1]{action,state}:\n  "init","kept — %s already exists"\n' "$CFG"
    exit 0
  fi
  TPL="$ROOT/config/agents.yaml.example"
  [ -r "$TPL" ] || { printf 'error: template missing: %s\n' "$TPL" >&2; exit 1; }
  mkdir -p "$(dirname "$CFG")" 2>/dev/null || true
  cp "$TPL" "$CFG" || { printf 'error: could not write %s\n' "$CFG" >&2; exit 1; }
  printf 'agents-config[1]{action,path}:\n  "init","%s"\n' "$CFG"
  exit 0
fi


[ -r "$CFG" ] || { printf 'error: config not found: %s\nhelp: create %s\n' "$CFG" "$CFG" >&2; exit 1; }

python3 - "$ROOT" "$CFG" "$RESOLVED" "$ACTION" "$@" <<'PY'
import sys, os, json, glob, re, urllib.request
root, cfg_path, resolved_path, action = sys.argv[1:5]
args = sys.argv[5:]
try:
    import yaml
except Exception:
    print('error: python3 has no PyYAML'); sys.exit(1)

cfg = yaml.safe_load(open(cfg_path)) or {}
default_model   = cfg.get("default_model") or ""
default_harness = cfg.get("default_harness") or "opencode"
agents    = cfg.get("agents") or {}
providers = cfg.get("providers") or {}

def spec_of(a):
    return agents.get(a) if isinstance(agents.get(a), dict) else {"model": agents.get(a)}

def model_of(a):
    return spec_of(a).get("model") or default_model

hcfg = cfg.get("harness") or {}
local_harness   = hcfg.get("local") or "pi"
online_harness  = hcfg.get("online") or "opencode"
local_providers = set(hcfg.get("local_providers") or [])
prov_map        = hcfg.get("providers") or {}

def is_local(a):
    return model_of(a).split("/", 1)[0] in local_providers

def harness_of(a):
    return spec_of(a).get("harness") or (local_harness if is_local(a) else online_harness)

def harness_model(a):
    """The model string as the chosen harness expects it (provider renamed for pi)."""
    h = harness_of(a)
    m = resolve_model(model_of(a))
    prov, _, short = m.partition("/")
    if h in ("pi", "hermes"):
        return f"{prov_map.get(prov, {}).get(h, prov)}/{short}"
    return m

# --- exact-id resolution for local routers -------------------------------
def server_ids(base_url):
    """The ids a server reports at <base_url>/models (base_url ends with /v1)."""
    try:
        with urllib.request.urlopen(base_url.rstrip("/") + "/models", timeout=4) as r:
            d = json.load(r)
        return [m.get("id") for m in (d.get("data") or []) if m.get("id")]
    except Exception:
        return []

def resolve_map():
    """provider -> {alias: exact_id} for any model that is not an exact id."""
    out = {}
    for pname, pspec in providers.items():
        base = pspec.get("base_url")
        if not base:
            continue
        ids = server_ids(base)
        for mid in (pspec.get("models") or []):
            if mid in ids:
                out.setdefault(pname, {})[mid] = mid
                continue
            cands = [i for i in ids if i.split("@")[0] == mid]
            if len(cands) == 1:
                out.setdefault(pname, {})[mid] = cands[0]
    return out

def resolve_model(m):
    """Expand a bare `provider/alias` to the provider's exact served id."""
    if "/" not in m:
        return m
    p, _, short = m.partition("/")
    exact = resolve_map().get(p, {}).get(short)
    return f"{p}/{exact}" if exact else m

# --- actions -------------------------------------------------------------
if action == "show":
    rows = sorted(agents)
    print(f'agents-config[{len(rows)}]{{agent,harness,model}}:')
    for a in rows:
        print(f'  "{a}","{harness_of(a)}","{harness_model(a)}"')
    sys.exit(0)

if action == "resolve":
    changed = []
    for a in sorted(agents):
        m = model_of(a); r = resolve_model(m)
        if r != m:
            changed.append(f"{a}: {m} -> {r}")
    if changed:
        print(f'agents-resolve[{len(changed)}]{{agent,from,to}}:')
        for c in changed:
            a, rest = c.split(": ", 1); frm, to = rest.split(" -> ")
            print(f'  "{a}","{frm}","{to}"')
    else:
        print('agents-resolve[1]{state}:\n  "all models are exact ids"')
    sys.exit(0)

if action == "get":
    if len(args) < 2:
        print('error: get needs <agent> <harness|model>'); sys.exit(2)
    a, key = args[0], args[1]
    if os.path.exists(resolved_path):
        try:
            cached = json.load(open(resolved_path)).get(a, {})
            if key in cached:
                print(cached[key]); sys.exit(0)
        except Exception:
            pass
    print(harness_of(a) if key == "harness" else harness_model(a))
    sys.exit(0)

if action != "apply":
    print(f'error: unknown action {action}'); sys.exit(2)

changed = []
rmap = resolve_map()

# 1. Canonical agent profiles — set `model:` where `name:` matches.
for p in sorted(glob.glob(os.path.join(root, ".agents/agents/*.md"))):
    txt = open(p).read()
    m = re.search(r'^name:\s*(\S+)', txt, re.M)
    if not m or m.group(1) not in agents:
        continue
    a = m.group(1)
    new = resolve_model(model_of(a))
    new_txt, n = re.subn(r'^model:.*$', f'model: {new}', txt, count=1, flags=re.M)
    if n and new_txt != txt:
        open(p, "w").write(new_txt)
        changed.append(f"md:{a}")

# 2. Project opencode.json — providers + agent models + runnable primaries.
oc = os.path.join(root, "opencode.json")
if os.path.exists(oc):
    d = json.load(open(oc))
    prov = d.setdefault("provider", {})
    for name, pspec in providers.items():
        entry = prov.setdefault(name, {})
        entry.setdefault("npm", pspec.get("npm", "@ai-sdk/openai-compatible"))
        entry.setdefault("name", pspec.get("name", name))
        if pspec.get("base_url"):
            entry.setdefault("options", {})["baseURL"] = pspec["base_url"]
        models = entry.setdefault("models", {})
        for mid in (pspec.get("models") or []):
            exact = rmap.get(name, {}).get(mid, mid)
            models.setdefault(exact, {"name": exact})
        changed.append(f"provider:{name}")
    ablock = d.setdefault("agent", {})
    for a in agents:
        m = resolve_model(model_of(a))
        if a in ablock:
            if ablock[a].get("model") != m:
                ablock[a]["model"] = m; changed.append(f"oc:{a}")
        if spec_of(a).get("primary"):
            entry = ablock.setdefault(a, {})
            entry["mode"] = "primary"
            entry["model"] = m
            entry.setdefault("description", f"{a} — primary (from config/agents.yaml)")
            changed.append(f"primary:{a}")
    with open(oc, "w") as fh:
        json.dump(d, fh, indent=2); fh.write("\n")

# 3. Cache the resolved combination for get / bin/agent-run.sh.
os.makedirs(os.path.dirname(resolved_path), exist_ok=True)
json.dump({a: {"harness": harness_of(a), "model": harness_model(a)}
           for a in agents}, open(resolved_path, "w"), indent=2)

print(f'agents-config[1]{{action,changed}}:\n  "apply","{",".join(changed) or "none"}"')
PY
