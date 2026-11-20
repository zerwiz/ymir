#!/usr/bin/env bash
# model-register.sh — register the chosen model with Ymir, in the hoard.
#
# Writes the same model the engine serves into the operator's private
# config/agents.<host>.yaml OVERLAY (which bin/agents-config.sh deep-merges over
# config/agents.yaml). This keeps Ymir and Smíðja on ONE model road: the hoard's
# default_model + providers block, resolved by the one resolver — no second
# translation table, and the operator's annotated base file is never rewritten.
#
# Usage:
#   model-register.sh --provider <p> --model <id> [--base-url URL] [--ctx N]
#   model-register.sh --show
#   model-register.sh --version
#
# Exit: 0 written/no-op, 2 usage, 5 write failed.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

PROVIDER=""; MODEL=""; BASE_URL=""; CTX=""; SHOW=0
while [ $# -gt 0 ]; do case "$1" in
  --provider) PROVIDER="${2-}"; shift 2 ;;
  --provider=*) PROVIDER="${1#--provider=}"; shift ;;
  --model) MODEL="${2-}"; shift 2 ;;
  --model=*) MODEL="${1#--model=}"; shift ;;
  --base-url) BASE_URL="${2-}"; shift 2 ;;
  --base-url=*) BASE_URL="${1#--base-url=}"; shift ;;
  --ctx) CTX="${2-}"; shift 2 ;;
  --ctx=*) CTX="${1#--ctx=}"; shift ;;
  --show) SHOW=1; shift ;;
  *) shift ;;
esac; done

HOST="$(hostname -s 2>/dev/null || hostname)"
OVERLAY="$YMIR_SETTINGS_DIR/agents.$HOST.yaml"

if [ "$SHOW" = 1 ]; then
  if [ -r "$OVERLAY" ]; then cat "$OVERLAY"; else printf '# no overlay at %s\n' "$OVERLAY"; fi
  exit 0
fi

[ -n "$PROVIDER" ] && [ -n "$MODEL" ] || { printf 'error: usage: bin/model-register.sh --provider P --model ID [--base-url URL]\n' >&2; exit 2; }

mkdir -p "$YMIR_SETTINGS_DIR"
python3 - "$OVERLAY" "$PROVIDER" "$MODEL" "${BASE_URL:-}" "${CTX:-0}" <<'PY'
import json, sys
try:
    import yaml
except Exception:
    print("error: python3 has no PyYAML"); sys.exit(5)
overlay_path, provider, model, base_url, ctx = sys.argv[1:6]

try:
    cfg = yaml.safe_load(open(overlay_path)) or {}
    if not isinstance(cfg, dict):
        cfg = {}
except Exception:
    cfg = {}

cfg["default_model"] = f"{provider}/{model}"
providers = cfg.setdefault("providers", {})
entry = providers.setdefault(provider, {})
entry.setdefault("npm", "@ai-sdk/openai-compatible")
entry.setdefault("name", f"{provider} (local)")
if base_url:
    entry["base_url"] = base_url
models = entry.setdefault("models", [])
if not isinstance(models, list):
    models = []; entry["models"] = models
if model not in models:
    models.append(model)

header = ("# Machine overlay written by bin/model-register.sh — do not hand-edit lightly.\n"
          "# Deep-merges over config/agents.yaml (the one model road). It names the\n"
          "# model this seat stands up; the base file stays the operator's.\n")
with open(overlay_path, "w") as fh:
    fh.write(header)
    yaml.safe_dump(cfg, fh, sort_keys=False, default_flow_style=False)
print(f"model-register[1]{{host_overlay,provider,model}}:\n  \"{overlay_path}\",\"{provider}\",\"{model}\"")
PY
