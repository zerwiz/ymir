#!/usr/bin/env bash
# dispatch-profile.sh — decide which Eindri dispatch profile is ACTIVE, and
# derive a real one from the machine.
#
# config/eindri-dispatch.json ships as a TEMPLATE with unfilled model tokens
# (<your-model-id>). A profile that still carries those tokens must never steer
# dispatch: it would silently pick a harness/model the machine cannot run.
# FIX 2026-09-24: the old rule was "file exists ⇒ active" — on heimdall the
# template counted as ACTIVE, its first rule named opencode, Brokk obeyed it,
# and an opencode worker was raised though the fleet law is pi-primary.
#
#   bin/dispatch-profile.sh active              # the ACTIVE profile path, or none
#   bin/dispatch-profile.sh validate [file]     # a profile is coherent + servable
#   bin/dispatch-profile.sh derive [--out P]    # write a machine-derived profile
#   bin/dispatch-profile.sh --version
#
# Activation order (the override wins):
#   1. $YMIR_HOME/hodd/config/eindri-dispatch.json     (the private override)
#   2. $BROKK_HOME/config/eindri-dispatch.json         (repo/private config dir)
# A candidate is ACTIVE only when it parses, carries no unfilled <...> model
# tokens, and every rule's model is servable by its harness on this machine.
# With no active profile, einherjar-spawn.sh resolves harness/model from the
# MACHINE (see assets/eindri-orchestration.md §5) instead of any template.
#
# `derive` writes a profile from config/agents.yaml (the Allfather's own
# combination) plus the pi catalog (pi --list-models) and the local-provider
# list — nothing is invented. The installer calls it so a fresh host gets a
# REAL profile, not the template.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/hoard-lib.sh" ]; then . "$_yh/bin/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-$ROOT}}"
CONFIG="${BROKK_CONFIG_OVERRIDE:-$BROKK_HOME/config}"

# The operator's settings and secrets live in the home they chose (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_root _HOARD 2>/dev/null || _HOARD=
hoard_state_dir YMIR_STATE_DIR 2>/dev/null || true

CFG="${YMIR_AGENTS_YAML:-$YMIR_SETTINGS_DIR/agents.yaml}"
OVERRIDE=""
[ -d "${_HOARD:-}/config" ] && OVERRIDE="$_HOARD/config/eindri-dispatch.json"
REPO_FILE="$CONFIG/eindri-dispatch.json"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-active}"; shift || true

# The servable judgement, shared by active/validate/derive. python3 owns the
# JSON, YAML, and the pi catalog (pi --list-models).
serve_judge() { # <profile-path> <agents-yaml> <pi-catalog-cmd-json?>  -> verdict on stdout
  local profile=$1 cmd=
  [ -n "${2:-}" ] && cmd="pi --list-models" || cmd=""
  python3 - "$profile" "$CFG" "$cmd" <<'PY'
import sys, json, re, subprocess
profile, cfg_path, listcmd = sys.argv[1:4]
def fail(kind, msg):
    print(f'dispatch-profile[1]{{{kind}}}:\n  "invalid","{msg}"')
    raise SystemExit(1)
try:
    d = json.load(open(profile))
except Exception as e:
    fail("json", str(e))
tokens = []
def collect(node):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "model" and isinstance(v, str):
                tokens.append(v)
            else:
                collect(v)
    elif isinstance(node, list):
        for v in node: collect(v)
collect(d.get("rules") or [])
collect(d.get("default") or [])
# 1. an unfilled template token never steers
for t in tokens:
    if not t or "<" in t or "your-model" in t:
        fail("active", f"an unfilled `<...>` model token steers a rule ({t!r}); the profile is NOT ACTIVE — derive one (bin/dispatch-profile.sh derive) or write $YMIR_HOME/hodd/config/eindri-dispatch.json")
# 2. the harness set is the verified launch set
verified = {"opencode", "pi", "pi-signed"}
try:
    import yaml
    yaml_cfg = {}
    if cfg_path and os.path.exists(cfg_path):
        yaml_cfg = yaml.safe_load(open(cfg_path)) or {}
except Exception:
    yaml_cfg = {}
hcfg = yaml_cfg.get("harness") or {}
local_providers = set(hcfg.get("local_providers") or [])
def looks_local(p):
    return p in local_providers or p.startswith("llama") or "llama" in p or p in ("lmstudio",)
# 3. the servable catalog for local providers
catalog = set()
if listcmd:
    try:
        out = subprocess.check_output(listcmd.split(), text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2 and "@" in parts[1]:
                catalog.add(f"{parts[0]}/{parts[1]}")
    except Exception:
        pass
def check_rule(name, harness, model):
    if harness not in verified:
        return f"rule {name!r} names harness {harness!r} which is not on the verified launch set ({' '.join(sorted(verified))})"
    if not model:
        return None
    if "/" not in model or model.startswith("<"):
        return f"rule {name!r} model token {model!r} is not a servable provider/model token"
    prov = model.split("/", 1)[0]
    if harness in ("pi", "pi-signed"):
        if model not in catalog:
            return f"rule {name!r}: pi cannot serve {model!r} (absent from the live pi catalog)"
    elif looks_local(prov):
        if model not in catalog:
            return f"rule {name!r}: harness opencode cannot serve LOCAL model {model!r} (not in the pi catalog)"
    return None
for i, rule in enumerate(d.get("rules") or []):
    for use in (rule.get("use") or []):
        if not isinstance(use, dict): continue
        if "resolve" in use: continue
        e = check_rule(rule.get("when") or f"rules[{i}]", use.get("harness") or "", use.get("model") or "")
        if e: fail("servable", e)
for i, use in enumerate(d.get("default") or []):
    if not isinstance(use, dict): continue
    e = check_rule(f"default[{i}]", use.get("harness") or "", use.get("model") or "")
    if e: fail("servable", e)
print('dispatch-profile[1]{verdict}:\n  "ok"')
PY
}

active() {
  # 1. the private override wins when present AND coherent.
  if [ -n "$OVERRIDE" ] && [ -f "$OVERRIDE" ]; then
    if serve_judge "$OVERRIDE" >/dev/null 2>&1; then
      printf 'dispatch-profile[1]{active,path,source}:\n  "yes","%s","override ($YMIR_HOME/hodd/config)"\n' "$OVERRIDE"
      return 0
    fi
    printf 'dispatch-profile[1]{active,path,why}:\n  "no","%s","override present but not cookable — fix it or remove it so the machine resolution governs"\n' "$OVERRIDE" >&2
    return 1
  fi
  # 2. the repo/private config dir profile — only when it is a real profile.
  if [ -f "$REPO_FILE" ]; then
    if serve_judge "$REPO_FILE" >/dev/null 2>&1; then
      printf 'dispatch-profile[1]{active,path,source}:\n  "yes","%s","repo config"\n' "$REPO_FILE"
      return 0
    fi
    printf 'dispatch-profile[1]{active,path,why}:\n  "no","%s","the shipped template carries unfilled model tokens — it is NOT active; the machine resolution governs until a real profile exists"\n' "$REPO_FILE" >&2
    return 1
  fi
  printf 'dispatch-profile[1]{active,path,why}:\n  "no","","no dispatch profile file exists; machine resolution governs"\n' >&2
  return 1
}

validate() {
  local file=${1:-$REPO_FILE}
  [ -f "$file" ] || { printf 'dispatch-profile[1]{validate}:\n  "error","no file: %s"\n' "$file" >&2; exit 1; }
  if serve_judge "$file" >/dev/null 2>&1; then
    printf 'dispatch-profile[1]{validate,file,state}:\n  "ok","%s","coherent and servable on this machine"\n' "$file"
    exit 0
  fi
  serve_judge "$file" | sed 's/^/  /'
  printf 'dispatch-profile[1]{validate,file,state}:\n  "fail","%s","see verdict above"\n' "$file" >&2
  exit 1
}

derive() {
  local out=
  while [ $# -gt 0 ]; do
    case "$1" in
      --out) out="${2-}"; shift 2 ;;
      --out=*) out=${1#--out=} ; shift ;;
      *) printf 'error: unknown flag %s\nhelp: bin/dispatch-profile.sh derive [--out PATH]\n' "$1" >&2; exit 2 ;;
    esac
  done
  [ -n "$out" ] || out="$ROOT/config/eindri-dispatch.json"
  local verdict
  verdict=$(python3 - "$CFG" "$out" <<'PY'
import sys, os, json, subprocess
cfg_path, out_path = sys.argv[1:3]
try:
    import yaml
except Exception:
    print("error: PyYAML missing"); raise SystemExit(1)
cfg = yaml.safe_load(open(cfg_path)) or {} if cfg_path and os.path.exists(cfg_path) else {}
hcfg = cfg.get("harness") or {}
local_harness  = hcfg.get("local") or "pi"
online_harness = hcfg.get("online") or "opencode"
local_providers = set(hcfg.get("local_providers") or [])
default_model = cfg.get("default_model") or ""
def looks_local(p):
    return p in local_providers or p.startswith("llama") or "llama" in p or p in ("lmstudio",)
# the pi catalog — the machine's served truth
catalog = []
try:
    out = subprocess.check_output(["pi", "--list-models"], text=True, stderr=subprocess.DEVNULL)
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and "@" in parts[1]:
            catalog.append((parts[0], parts[1]))
except Exception:
    pass
# the default model: agents.yaml's own; verify it exists in the catalog, else
# fall back to the first served local model.
model = default_model
if model and model not in {f"{p}/{m}" for p, m in catalog} and (looks_local(model.split("/",1)[0])):
    model = ""
if not model and catalog:
    model = f"{catalog[0][0]}/{catalog[0][1]}"
harness = local_harness if (model and looks_local(model.split("/",1)[0])) else online_harness
profile = {
  "version": 1,
  "platform": "ymir",
  "notes": "Derived from THIS machine on " + os.popen("date -u +%Y-%m-%d").read().strip() + " — config/agents.yaml + the live pi catalog. Brokk reads these rules before dispatching an Eindri and passes only concrete --harness/--model/--effort flags to bin/einherjar-spawn.sh. Effort values: low|medium|high|xhigh|max.",
  "rules": [
    {"when": "General implementation, refactoring, or bug fixes in a codebase",
     "use": [{"harness": harness, "model": model, "effort": "medium"}],
     "why": f"the machine's default harness ({harness}) and default model ({model or 'harness default'}) for implementation work"},
    {"when": "Deep investigation, diagnosis, planning, or ambiguous design work requiring deep reasoning",
     "use": [{"harness": harness, "model": model, "effort": "xhigh"}],
     "why": "maximum reasoning on the machine's default harness"},
    {"when": "Trivial mechanical edits such as rote renames, formatting sweeps, or simple file gathering",
     "use": [{"harness": harness, "model": model, "effort": "low"}],
     "why": "fast, cheap profile for narrow low-ambiguity tasks"},
    {"when": "Long-running autonomous or background execution: supervision branches, unattended sweeps, or persistent workers",
     "use": [{"harness": "pi", "effort": "medium"}],
     "why": "pi is the verified runner for persistent and background workers; omitting model uses pi's configured default"},
    {"when": "The Allfather names a model, a family/quant, or a locality (local/online)",
     "use": [{"resolve": "bin/model-resolve.sh resolve \"<request>\"",
              "then": "pass the returned --harness/--model to bin/einherjar-spawn.sh"}],
     "why": "resolve a friendly request to an exact servable id: local -> " + local_harness + ", online -> " + online_harness + ". If it returns unresolved, ask the Allfather; never guess. Local runs are serialized by bin/local-model-lock.sh."}
  ],
  "default": [{"harness": harness, "model": model, "effort": "medium"}]
}
os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
with open(out_path, "w") as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {out_path} (harness={harness}, model={model or '(harness default)'})")
PY
)
  [ -n "$verdict" ] || { printf 'dispatch-profile[1]{derive}:\n  "error","python derivation failed"\n' >&2; exit 1; }
  printf 'dispatch-profile[1]{derive,out}:\n  "%s","%s"\n' "$verdict" "$out"
}

case "$ACTION" in
  active)   active; exit $? ;;
  validate) validate "$@"; exit $? ;;
  derive)   derive "$@"; exit $? ;;
  *) printf 'error: unknown action %s\nhelp: bin/dispatch-profile.sh active|validate|derive\n' "$ACTION" >&2; exit 2 ;;
esac