#!/usr/bin/env bash
# model-resolve.sh — resolve a human model request to a concrete harness+model.
#
#   bin/model-resolve.sh resolve "qwen 3.6 iq2"
#   bin/model-resolve.sh resolve "deepseek"
#   bin/model-resolve.sh resolve "llama.cpp/qwen3.6-35b-a3b@q2_k_xl"
#   bin/model-resolve.sh list
#
# Sources of truth: config/agents.yaml (providers, harness rule, local models)
# and the live local catalog (`pi --list-models`). Local → pi, online → opencode.
# Prints harness, provider, model, locality, confidence. Low confidence means the
# caller should ASK the Allfather (ask_user_question), not guess.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG="${YMIR_AGENTS_YAML:-$ROOT/config/agents.yaml}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-resolve}"; shift || true
REQ="${*:-}"

python3 - "$ROOT" "$CFG" "$ACTION" "$REQ" <<'PY'
import sys, os, re, subprocess
root, cfg_path, action, req = sys.argv[1:5]
try:
    import yaml
except Exception:
    print("error: PyYAML missing"); sys.exit(1)
cfg = yaml.safe_load(open(cfg_path)) or {}
hcfg = cfg.get("harness") or {}
LOCAL_H = hcfg.get("local") or "pi"
ONLINE_H = hcfg.get("online") or "opencode"
LOCAL_PROVIDERS = set(hcfg.get("local_providers") or [])
providers = cfg.get("providers") or {}

# online models the config already knows (default + every agent's model, non-local)
online_models = set()
_dm = cfg.get("default_model")
if _dm and "/" in _dm:
    online_models.add(_dm)
for _a, _s in (cfg.get("agents") or {}).items():
    _m = _s.get("model") if isinstance(_s, dict) else _s
    if _m and "/" in _m:
        _p = _m.split("/", 1)[0]
        if _p not in LOCAL_PROVIDERS and "llama" not in _p and _p not in ("lmstudio",):
            online_models.add(_m)

def pi_catalog():
    try:
        out = subprocess.check_output(["pi", "--list-models"], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return []
    rows = []
    for line in out.splitlines():
        p = line.split()
        if len(p) >= 2 and "@" in p[1]:
            rows.append((p[0], p[1]))
    return rows

catalog = pi_catalog()  # (provider, model) locally servable
# local providers: from config + names that look local
def is_local_provider(p):
    return p in LOCAL_PROVIDERS or p.startswith("llama") or p in ("lmstudio",) or "llama" in p or p.startswith("llamacpp")

QUANT_ALIAS = {"iq2":"q2_k_xl","iq-2":"q2_k_xl","q2":"q2_k_xl","iq1":"q2_k_xl",
               "iq3":"iq3_s","q3":"iq3_s","q4":"q4_k_s","q5":"q5_k_m","q6":"q6_k","q8":"q8_0"}

def tokens(s):
    return re.findall(r"[a-z0-9]+(?:\.[0-9]+)?", s.lower())

if action == "list":
    loc = [m for p,m in catalog if is_local_provider(p)]
    print(f'model-catalog{{local:{len(loc)}}}["{'" ,"'.join(sorted(set(loc)))}"]')
    online = sorted({m for p in providers for m in (providers[p].get("models") or []) if isinstance(providers[p], dict)})
    print(f'configured-online{len(online)}["{'" ,"'.join(online)}"]')
    sys.exit(0)

if not req.strip():
    print("error: need a model request"); sys.exit(2)

req_l = req.strip().lower()
# 1. exact provider/model (optionally @quant)
if "/" in req and "@" in req:
    p, m = req.split("/", 1)
    print(f'model-resolve[1]{{request,locality,harness,provider,model,confidence}}:\n  "{req}","{"local" if is_local_provider(p) else "online"}","{LOCAL_H if is_local_provider(p) else ONLINE_H}","{p}","{m}","exact"')
    sys.exit(0)

# 2. fuzzy against the local catalog
rt = tokens(req_l)
want_provider = None
want_quant = None
for t in rt:
    if t in QUANT_ALIAS: want_quant = QUANT_ALIAS[t]
    if t in ("local",): want_provider = "local"
    if t in ("online","cloud","hosted"): want_provider = "online"

best = None; best_score = 0.0
for p, m in catalog:
    if not is_local_provider(p): continue
    mt = tokens(m)
    score = float(sum(1 for t in rt if t in mt))
    # quant proximity
    if want_quant and want_quant.replace("_","") in m.replace("_",""):
        score += 2
    # family hints
    if "qwen" in rt and "qwen" in m: score += 2
    # tie-breaks: prefer newer version, then larger size (a more capable model)
    ver = re.search(r"(\d+\.\d+)", m)
    sz  = re.search(r"(\d+)b", m)
    if ver: score += min(float(ver.group(1)), 9.0) / 100.0
    if sz:  score += min(int(sz.group(1)), 100) / 1000.0
    if score > best_score:
        best_score = score; best = (p, m)

if best and best_score >= 2:
    conf = "high" if best_score >= 5 else "medium"
    print(f'model-resolve[1]{{request,locality,harness,provider,model,confidence}}:\n  "{req}","local","{LOCAL_H}","{best[0]}","{best[1]}","{conf}"')
    sys.exit(0)

# 3. online: match a configured online provider by name
for t in rt:
    for pname, pspec in providers.items():
        if pname.lower().replace(".","") in t.replace(".",""):
            models = (pspec.get("models") or []) if isinstance(pspec, dict) else []
            m = models[0] if models else ""
            print(f'model-resolve[1]{{request,locality,harness,provider,model,confidence}}:\n  "{req}","online","{ONLINE_H}","{pname}","{m}","medium"')
            sys.exit(0)

# 3b. online: fuzzy against the configured online models
best_o = None; best_os = 0
for m in online_models:
    p_, m_ = m.split("/", 1)
    sc = sum(1 for t in rt if t in m_)
    if sc > best_os:
        best_os = sc; best_o = (p_, m_)
if best_o and best_os >= 1:
    print(f'model-resolve[1]{{request,locality,harness,provider,model,confidence}}:\n  "{req}","online","{ONLINE_H}","{best_o[0]}","{best_o[1]}","medium"')
    sys.exit(0)

# 4. unknown → ask
print(f'model-resolve[1]{{request,resolution,ask}}:\n  "{req}","unresolved","yes"')
print('help: bin/model-resolve.sh list  — or ask the Allfather with ask_user_question')
sys.exit(0)
PY
