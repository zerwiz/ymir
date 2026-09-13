#!/usr/bin/env bash
# models-detect.sh — detect the LOCAL model runtimes present on this machine and
# emit a Pi models.json provider fragment. It never assumes llama.cpp: it reports
# what IS here (a llama.cpp/llama-swap server, an LM Studio GGUF tree, Ollama).
#
# Coding wants a wide window: detected models are suggested at >= 80000 context.
#
# Usage:
#   models-detect.sh                 # human report + the JSON fragment
#   models-detect.sh --json          # only the JSON fragment
#   models-detect.sh --write [--force]  # merge providers into ~/.pi/agent/models.json
#                                        (adds only missing providers unless --force)
#   models-detect.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_JSON="${PI_MODELS_JSON:-$HOME/.pi/agent/models.json}"
CODING_CTX="${YMIR_CODING_CTX:-80000}"
MODE="report"; WRITE=0; FORCE=0

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --json) MODE=json; shift ;;
    --write) WRITE=1; shift ;;
    --force) FORCE=1; shift ;;
    *) shift ;;
  esac
done
have() { command -v "$1" >/dev/null 2>&1; }

# ── detect ────────────────────────────────────────────────────────────────────
# http_ids <url> -> server model ids, one per line
http_ids() {
  curl -fsS --max-time 3 "$1" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
for m in d.get("data", []) or []:
    i=m.get("id")
    if i: print(i)
' 2>/dev/null
}
ollama_ids() {
  curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
for m in d.get("models", []) or []:
    n=m.get("name")
    if n: print(n)
' 2>/dev/null
}

LLAMACPP_URL=""; OLLAMA=0; LMSTUDIO_TREE=0
for u in http://127.0.0.1:8080/v1/models http://127.0.0.1:8090/v1/models; do
  ids="$(http_ids "$u")" && [ -n "$ids" ] && { LLAMACPP_URL="${u%/models}"; break; }
done
[ -d "$HOME/.lmstudio/models" ] && LMSTUDIO_TREE=1
have ollama && OLLAMA=1

# ── fragment ──────────────────────────────────────────────────────────────────
FRAGMENT="$(MODELS_JSON="$MODELS_JSON" CODING_CTX="$CODING_CTX" \
  LLAMACPP_URL="${LLAMACPP_URL:-http://127.0.0.1:8080/v1}" LMSTUDIO_TREE="$LMSTUDIO_TREE" OLLAMA="$OLLAMA" \
  python3 <<'PY'
import json, os, subprocess

ctx = int(os.environ.get("CODING_CTX", "80000"))
providers = {}

llama_url = os.environ.get("LLAMACPP_URL", "")
lm_tree = os.environ.get("LMSTUDIO_TREE") == "1"
ollama = os.environ.get("OLLAMA") == "1"

def served(url):
    try:
        out = subprocess.run(["curl", "-fsS", "--max-time", "3", url + "/models"],
                             capture_output=True, text=True).stdout
        return [m["id"] for m in json.loads(out).get("data", []) if m.get("id")]
    except Exception:
        return []

ids = served(llama_url) if llama_url else []
if ids or lm_tree:
    models = [{
        "id": i, "name": i, "contextWindow": ctx, "maxTokens": 16384,
        "reasoning": False, "samplingParams": {"temperature": 0.7, "top_p": 0.95},
    } for i in ids] or [{"id": "<run-the-router>", "name": "start llama.cpp/llama-swap, then re-run models-detect.sh --write",
                          "contextWindow": ctx, "maxTokens": 16384}]
    providers["llamacpp"] = {
        "baseUrl": llama_url or "http://127.0.0.1:8080/v1",
        "api": "openai-completions", "apiKey": "sk-not-key-required",
        "compat": {"supportsDeveloperRole": False, "supportsReasoningEffort": False},
        "models": models,
    }

if ollama:
    try:
        out = subprocess.run(["curl", "-fsS", "--max-time", "3", "http://127.0.0.1:11434/api/tags"],
                             capture_output=True, text=True).stdout
        names = [m["name"] for m in json.loads(out).get("models", []) if m.get("name")]
    except Exception:
        names = []
    providers["ollama"] = {
        "baseUrl": "http://127.0.0.1:11434/v1",
        "api": "openai-completions", "apiKey": "sk-not-key-required",
        "models": [{"id": n, "name": n, "contextWindow": ctx, "maxTokens": 16384} for n in names],
    }

print(json.dumps({"providers": providers}, indent=2))
PY
)"

# ── emit / write ──────────────────────────────────────────────────────────────
if [ "$WRITE" = 1 ]; then
  MODELS_JSON="$MODELS_JSON" FORCE="$FORCE" FRAGMENT="$FRAGMENT" python3 <<'PY'
import json, os, sys
path = os.environ["MODELS_JSON"]
frag = json.loads(os.environ["FRAGMENT"])
force = os.environ.get("FORCE") == "1"
os.makedirs(os.path.dirname(path), exist_ok=True)
try:
    with open(path) as f: doc = json.load(f)
except Exception:
    doc = {}
doc.setdefault("providers", {})
added = 0
for name, spec in frag.get("providers", {}).items():
    if name in doc["providers"] and not force:
        continue
    doc["providers"][name] = spec
    added += 1
with open(path, "w") as f: json.dump(doc, f, indent=2)
print(f"models-detect: wrote {added} provider(s) to {path}")
PY
  exit 0
fi

if [ "$MODE" = "json" ]; then printf '%s\n' "$FRAGMENT"; exit 0; fi

runtimes=""
[ -n "$LLAMACPP_URL" ] && runtimes="$runtimes llama.cpp@${LLAMACPP_URL#http://}"
[ "$LMSTUDIO_TREE" = 1 ] && runtimes="$runtimes lmstudio-tree"
[ "$OLLAMA" = 1 ] && runtimes="$runtimes ollama"
printf 'models-detect[1]{runtimes,coding_ctx,models_json}:\n  "%s","%s","%s"\n' "${runtimes:- none}" "$CODING_CTX" "$MODELS_JSON"
printf '%s\n' "$FRAGMENT"
if [ -z "$runtimes" ]; then
  printf 'note: no local runtime detected — install one (llama.cpp / LM Studio / Ollama) and re-run.\n' >&2
  printf 'note: llama.cpp (llama-server / llama-swap) is fastest on the GPU; for coding use >= %s context.\n' "$CODING_CTX" >&2
fi
