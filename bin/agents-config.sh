#!/usr/bin/env bash
# agents-config.sh — one YAML for the Allfather's agent/model combination.
#
#   bin/agents-config.sh show      # the current combination (TOON)
#   bin/agents-config.sh apply     # write it into the agents + project config
#   bin/agents-config.sh --version
#
# The single source is config/agents.yaml. `apply` sets `model:` in the canonical
# `.agents/agents/*.md` (matched by their `name:`) and in project `opencode.json`
# (agents + local providers). Nothing else in Ymir hardcodes a model.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG="$ROOT/config/agents.yaml"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-show}"

[ -r "$CFG" ] || { printf 'error: config not found: %s\nhelp: create %s\n' "$CFG" "$CFG" >&2; exit 1; }

python3 - "$ROOT" "$CFG" "$ACTION" <<'PY'
import sys, os, json, glob, re
root, cfg_path, action = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    import yaml
except Exception:
    print('error: python3 has no PyYAML'); sys.exit(1)

cfg = yaml.safe_load(open(cfg_path)) or {}
default = cfg.get("default_model") or ""
agents  = cfg.get("agents") or {}
providers = cfg.get("providers") or {}

def model_of(a):
    spec = agents.get(a)
    m = spec.get("model") if isinstance(spec, dict) else spec
    return m or default

if action == "show":
    rows = sorted(agents)
    print(f'agents-config[{len(rows)}]{{agent,model}}:')
    for a in rows:
        print(f'  "{a}","{model_of(a)}"')
    sys.exit(0)

if action != "apply":
    print(f'error: unknown action {action}'); sys.exit(2)

changed = []

# 1. Canonical agent profiles — set `model:` where `name:` matches.
for p in sorted(glob.glob(os.path.join(root, ".agents/agents/*.md"))):
    txt = open(p).read()
    m = re.search(r'^name:\s*(\S+)', txt, re.M)
    if not m:
        continue
    a = m.group(1)
    if a not in agents:
        continue
    new = model_of(a)
    new_txt, n = re.subn(r'^model:.*$', f'model: {new}', txt, count=1, flags=re.M)
    if n and new_txt != txt:
        open(p, "w").write(new_txt)
        changed.append(f"md:{a}")

# 2. Project opencode.json — providers (local servers) + agent models.
oc = os.path.join(root, "opencode.json")
if os.path.exists(oc):
    d = json.load(open(oc))
    prov = d.setdefault("provider", {})
    for name, spec in providers.items():
        entry = prov.setdefault(name, {})
        entry.setdefault("npm", spec.get("npm", "@ai-sdk/openai-compatible"))
        entry.setdefault("name", spec.get("name", name))
        if spec.get("base_url"):
            entry.setdefault("options", {})["baseURL"] = spec["base_url"]
        models = entry.setdefault("models", {})
        for mid in (spec.get("models") or []):
            models.setdefault(mid, {"name": mid})
        changed.append(f"provider:{name}")
    ablock = d.setdefault("agent", {})
    for a, spec in agents.items():
        m = spec.get("model") if isinstance(spec, dict) else spec
        if not m or a not in ablock:
            continue
        if ablock[a].get("model") != m:
            ablock[a]["model"] = m
            changed.append(f"oc:{a}")
    with open(oc, "w") as fh:
        json.dump(d, fh, indent=2)
        fh.write("\n")

print(f'agents-config[1]{{action,changed}}:\n  "apply","{",".join(changed) or "none"}"')
PY
