#!/usr/bin/env bash
# agents-config.sh — one YAML for the Allfather's agent/harness/model combination.
#
#   bin/agents-config.sh show                 # the current combination (TOON)
#   bin/agents-config.sh get <agent> <key>    # key: harness | model
#   bin/agents-config.sh default [--provider|--model|--harness]
#   bin/agents-config.sh provider-url <provider>   # the provider's base_url
#   bin/agents-config.sh resolve              # exact ids for local provider models
#   bin/agents-config.sh init                 # seed config/agents.yaml from the template
#   bin/agents-config.sh apply                # publish it into project harness config
#   bin/agents-config.sh --version
#
# Source of truth: config/agents.yaml (in the hoard, with a per-host overlay).
# The figures carry NO model: dispatch resolves each figure's model from this
# YAML by figure name (`get <figure> model`). `apply` writes local providers +
# agent models into project `opencode.json` and caches the resolved combination
# in `state/agents-resolved.json` (read by `get` and bin/agent-run.sh); it never
# rewrites a tracked `.agents/agents/*.md`.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
# The resolved cache lives in the runtime state, which belongs to the operator's
# home (Rule 04). Without this call YMIR_STATE_DIR is unbound and `set -u` kills
# every verb — show, get, resolve and apply all died on line 35.
hoard_state_dir YMIR_STATE_DIR
CFG="${YMIR_AGENTS_YAML:-$YMIR_SETTINGS_DIR/agents.yaml}"
RESOLVED="${YMIR_STATE_DIR}/agents-resolved.json"

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
  [ -r "$TPL" ] || TPL="$ROOT/.agents/config/agents.yaml.example"
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

# Per-machine overlay: config/agents.<hostname>.yaml (private) deep-merges over
# the base, so one repo runs different models/harness on different machines.
import socket
_host = (os.environ.get("YMIR_AGENTS_MACHINE") or socket.gethostname()).split(".")[0]
_overlay = os.path.join(os.path.dirname(cfg_path), f"agents.{_host}.yaml")
if os.path.exists(_overlay):
    def _merge(a, b):
        for k, v in (b or {}).items():
            if isinstance(v, dict) and isinstance(a.get(k), dict):
                _merge(a[k], v)
            else:
                a[k] = v
        return a
    cfg = _merge(cfg, yaml.safe_load(open(_overlay)) or {})
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

if action == "default":
    # The fallback smith's model, resolved from the hoard (overlay applied).
    # `--provider` / `--model` / `--harness` split it; bare prints provider/model.
    raw = resolve_model(default_model)
    if "--provider" in args:
        print(raw.split("/", 1)[0] if "/" in raw else "")
    elif "--model" in args:
        print(raw.split("/", 1)[1] if "/" in raw else raw)
    elif "--harness" in args:
        print(local_harness if "local" not in args else local_harness)
    else:
        print(raw)
    sys.exit(0)

if action == "provider-url":
    if len(args) < 1:
        print('error: provider-url needs <provider>'); sys.exit(2)
    print((providers.get(args[0]) or {}).get("base_url") or "")
    sys.exit(0)

if action == "get":
    if len(args) < 2:
        print('error: get needs <agent> <harness|model>'); sys.exit(2)
    a, key = args[0], args[1]
    # The cache is derived, not authoritative: use it only when it is newer than
    # the hoard YAML, else re-resolve live so a stale cache cannot serve an old model.
    fresh = os.path.exists(resolved_path) and (
        not os.path.exists(cfg_path) or os.path.getmtime(resolved_path) >= os.path.getmtime(cfg_path))
    if fresh:
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

# 1. Canonical agent profiles carry NO model (plan 56). The figure's model is
# resolved from the hoard by figure name at dispatch — `get <figure> model` —
# never written back into a tracked file. `apply` therefore does NOT touch
# .agents/agents/*.md; a machine whose roster differs must not dirty the tree.

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
        # opencode.json is OpenCode's file: only OpenCode agents belong in it. A
        # pi (or hermes) agent's model is that harness's id — e.g.
        # `llamacpp/qwen3.5-9b` — which OpenCode cannot resolve, so writing it
        # here would hand OpenCode an agent it cannot run. Skip them.
        if harness_of(a) != "opencode":
            continue
        m = resolve_model(model_of(a))
        # The roster DECLARES every figure it names. Before this, `apply` only
        # touched an agent already present in opencode.json (`if a in ablock`),
        # so a figure the roster knew but the config had never seen stayed
        # undeclared — and OpenCode never loaded it. The roster is the source of
        # truth; a name in it must reach the harness config.
        entry = ablock.setdefault(a, {})
        if entry.get("model") != m:
            entry["model"] = m; changed.append(f"oc:{a}")
        if spec_of(a).get("primary"):
            entry["mode"] = "primary"
            entry["model"] = m
            entry.setdefault("description", f"{a} — primary (from config/agents.yaml)")
            changed.append(f"primary:{a}")
    with open(oc, "w") as fh:
        json.dump(d, fh, indent=2); fh.write("\n")

# 2b. GLOBAL opencode.json — the same providers, so a run OUTSIDE this checkout
#     (another project, or a worktree before its link exists) still resolves the
#     local rail. The project file keeps per-agent models; the global file is the
#     machine's provider truth, resolved from the hoard like everything else.
home = os.environ.get("HOME", "")
if home:
    ocg = os.path.join(home, ".config/opencode/opencode.json")
    try:
        g = json.load(open(ocg))
    except Exception:
        g = {}
    gprov = g.setdefault("provider", {})
    for name, pspec in providers.items():
        entry = gprov.setdefault(name, {})
        entry.setdefault("npm", pspec.get("npm", "@ai-sdk/openai-compatible"))
        entry.setdefault("name", pspec.get("name", name))
        if pspec.get("base_url"):
            entry.setdefault("options", {})["baseURL"] = pspec["base_url"]
        models = entry.setdefault("models", {})
        for mid in (pspec.get("models") or []):
            exact = rmap.get(name, {}).get(mid, mid)
            models.setdefault(exact, {"name": exact})
        changed.append(f"gprovider:{name}")
    os.makedirs(os.path.dirname(ocg), exist_ok=True)
    with open(ocg, "w") as fh:
        json.dump(g, fh, indent=2); fh.write("\n")

# 3. Cache the resolved combination for get / bin/agent-run.sh.
os.makedirs(os.path.dirname(resolved_path), exist_ok=True)
json.dump({a: {"harness": harness_of(a), "model": harness_model(a)}
           for a in agents}, open(resolved_path, "w"), indent=2)

print(f'agents-config[1]{{action,changed}}:\n  "apply","{",".join(changed) or "none"}"')
PY
