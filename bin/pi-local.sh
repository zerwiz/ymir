#!/usr/bin/env bash
# pi-local.sh — run a Pi agent on a LOCAL model, reusable.
#
#   bin/pi-local.sh "<prompt>"                       # default local model
#   bin/pi-local.sh -m <model> "<prompt>"            # another llama.cpp model
#   PI_LOCAL_MODEL=... bin/pi-local.sh "<prompt>"
#
# The model id is the EXACT llama.cpp served id (…@quant). Defaults come from
# config/agents.yaml resolution; override with -m/--model or the env vars.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROVIDER="${PI_LOCAL_PROVIDER:-}"
MODEL="${PI_LOCAL_MODEL:-}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--model) MODEL=${2-}; shift 2 ;;
    -p|--provider) PROVIDER=${2-}; shift 2 ;;
    --) shift; break ;;
    -*) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
    *) break ;;
  esac
done

# Resolve provider + model from the hoard (config/agents.yaml default_model) when
# the env/flag did not name them. No concrete model lives in the tree.
if [ -z "$PROVIDER" ] || [ -z "$MODEL" ]; then
  _d="$([ -x "$SCRIPT_DIR/agents-config.sh" ] && "$SCRIPT_DIR/agents-config.sh" default 2>/dev/null)"
  [ -n "$PROVIDER" ] || PROVIDER="${_d%%/*}"
  [ -n "$MODEL" ] || MODEL="${_d#*/}"
fi
[ -n "$PROVIDER" ] && [ -n "$MODEL" ] || {
  printf 'error: no local model resolved — set PI_LOCAL_MODEL/PI_LOCAL_PROVIDER,\n'
  printf '  or add default_model to config/agents.yaml in your hoard\n' >&2
  exit 2
}

PROMPT="${*:-}"
[ -n "$PROMPT" ] || { printf 'error: usage: bin/pi-local.sh [-m model] "<prompt>"\n' >&2; exit 2; }

command -v pi >/dev/null 2>&1 || { printf 'error: pi is not on PATH\n' >&2; exit 1; }

printf 'pi-local[1]{provider,model}:\n  "%s","%s"\n' "$PROVIDER" "$MODEL" >&2
exec "$SCRIPT_DIR/local-model-lock.sh" pi --print --model "$PROVIDER/$MODEL" "$PROMPT"
