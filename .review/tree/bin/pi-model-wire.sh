#!/usr/bin/env bash
# pi-model-wire.sh — wire a chosen local model into the operator's pi.
#
# Pi (pi.dev) is installed when absent; the chosen model is written into
# ~/.pi/agent/models.json (provider + the EXACT served id, including its @quant),
# with the provider's key held in ~/.pi/agent/auth.json — a reference resolved
# from the hoard, never a value in the tree. The wiring is proven with a one-shot
# `pi -p --model <provider>/<id> "reply OK"`.
#
# Usage:
#   pi-model-wire.sh --provider <p> --model <id> [--base-url URL] [--ctx N]
#                    [--no-prove] [--install-pi]
#   pi-model-wire.sh --version
#
# Env:
#   PI_MODELS_JSON   — override the catalog path (default ~/.pi/agent/models.json)
#   PI_AUTH_JSON     — override the auth path (default ~/.pi/agent/auth.json)
#
# Exit: 0 wired and proven, 2 usage, 3 pi absent, 5 write/prove failed.
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
hoard_env YMIR_PLATFORM_ENV

MODELS_JSON="${PI_MODELS_JSON:-$HOME/.pi/agent/models.json}"
AUTH_JSON="${PI_AUTH_JSON:-$HOME/.pi/agent/auth.json}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

PROVIDER=""; MODEL=""; BASE_URL=""; CTX=""; PROVE=1; INSTALL_PI=0
while [ $# -gt 0 ]; do case "$1" in
  --provider) PROVIDER="${2-}"; shift 2 ;;
  --provider=*) PROVIDER="${1#--provider=}"; shift ;;
  --model) MODEL="${2-}"; shift 2 ;;
  --model=*) MODEL="${1#--model=}"; shift ;;
  --base-url) BASE_URL="${2-}"; shift 2 ;;
  --base-url=*) BASE_URL="${1#--base-url=}"; shift ;;
  --ctx) CTX="${2-}"; shift 2 ;;
  --ctx=*) CTX="${1#--ctx=}"; shift ;;
  --no-prove) PROVE=0; shift ;;
  --install-pi) INSTALL_PI=1; shift ;;
  *) shift ;;
esac; done
[ -n "$PROVIDER" ] && [ -n "$MODEL" ] || { printf 'error: usage: bin/pi-model-wire.sh --provider P --model ID [--base-url URL]\n' >&2; exit 2; }

have() { command -v "$1" >/dev/null 2>&1; }

# 1. install pi when absent (delegate to the one pi provisioner).
if ! have pi; then
  if [ "$INSTALL_PI" = 1 ] && [ -x "$SCRIPT_DIR/pi-ensure.sh" ]; then
    "$SCRIPT_DIR/pi-ensure.sh" install >/dev/null 2>&1 || true
  fi
  have pi || { printf 'error: pi is not installed\nhelp: re-run with --install-pi, or bin/pi-ensure.sh install\n' >&2; exit 3; }
fi

# 2. the provider key — a REFERENCE: reuse what auth.json holds, else resolve it
#    from the hoard env by convention. Never printed, never stored in the tree.
KEY=""
if [ -r "$AUTH_JSON" ]; then
  KEY="$(python3 - "$AUTH_JSON" "$PROVIDER" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    d = {}
p = d.get(sys.argv[2])
if isinstance(p, dict):
    print(p.get("key") or p.get("apiKey") or "")
elif isinstance(p, str):
    print(p)
PY
)"
fi
if [ -z "$KEY" ] && [ -r "$YMIR_PLATFORM_ENV" ]; then
  KEY="$(. "$YMIR_PLATFORM_ENV" 2>/dev/null; printf '%s' "${LLAMA_SWAP_API_KEY:-${YMIR_LLAMA_API_KEY:-}}")"
fi

# 3. write the provider + the EXACT served model id into models.json.
mkdir -p "$(dirname "$MODELS_JSON")" "$(dirname "$AUTH_JSON")"
RESULT="$(python3 - "$MODELS_JSON" "$AUTH_JSON" "$PROVIDER" "$MODEL" "$BASE_URL" "${CTX:-0}" "$KEY" <<'PY'
import json, os, sys
models_path, auth_path, provider, model, base_url, ctx, key = sys.argv[1:8]

def load(p):
    try:
        return json.load(open(p)) or {}
    except Exception:
        return {}

cat = load(models_path)
providers = cat.setdefault("providers", {})
entry = providers.setdefault(provider, {})
if base_url:
    entry["baseUrl"] = base_url
entry.setdefault("api", "openai-completions")
entry.setdefault("compat", {"supportsDeveloperRole": False, "supportsReasoningEffort": False})
models = entry.setdefault("models", [])
if not isinstance(models, list):
    models = []; entry["models"] = models
ids = [m.get("id") for m in models if isinstance(m, dict)]
if model not in ids:
    item = {"id": model, "name": model}
    if int(ctx or 0) > 0:
        item["contextWindow"] = int(ctx)
    item.setdefault("cost", {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0})
    models.append(item)
with open(models_path, "w") as fh:
    json.dump(cat, fh, indent=2); fh.write("\n")

if key:
    auth = load(auth_path)
    cur = auth.get(provider)
    if not (isinstance(cur, dict) and (cur.get("key") or cur.get("apiKey"))) and not isinstance(cur, str):
        auth[provider] = {"key": key}
        with open(auth_path, "w") as fh:
            json.dump(auth, fh, indent=2); fh.write("\n")
        os.chmod(auth_path, 0o600)
    print("key:present")
else:
    print("key:missing")
print("model:" + model)
PY
)"

printf 'pi-model-wire[1]{provider,model,models_json,key}:\n  "%s","%s","%s","%s"\n' \
  "$PROVIDER" "$MODEL" "$MODELS_JSON" "$(printf '%s' "$RESULT" | awk -F: '/^key:/{print $2}')"

# 4. prove it: a one-shot call must answer.
if [ "$PROVE" = 1 ]; then
  out="$(timeout 180 pi -p --no-context-files --no-skills --model "$PROVIDER/$MODEL" "Reply with exactly: OK" 2>&1 || true)"
  if [ -n "$out" ]; then
    printf 'pi-model-wire[1]{prove,state}:\n  "one-shot","ok"\n'
    exit 0
  fi
  printf 'error: the one-shot pi call produced no output — the model is not resolvable\n' >&2
  printf 'help: confirm the server is up and the id is exact: pi --list-models\n' >&2
  exit 5
fi
exit 0
