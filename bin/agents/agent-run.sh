#!/usr/bin/env bash
# agent-run.sh — run one agent's errand through the harness the Allfather chose.
#
#   bin/agents/agent-run.sh <agent> "<task>"
#
# The harness and model come from config/agents.yaml via bin/fleet/agents-config.sh.
# Any harness on PATH can be chosen per agent (pi | opencode | claude | codex |
# gemini | hermes | …), so the same smith can be run on whichever CLI you prefer.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

AGENT="${1:-}"; shift || true
TASK="${*:-}"
[ -n "$AGENT" ] && [ -n "$TASK" ] || { printf 'error: usage: bin/agents/agent-run.sh <agent> "<task>"\n' >&2; exit 2; }

HARNESS="$("$SCRIPT_DIR/../fleet/agents-config.sh" get "$AGENT" harness 2>/dev/null)"
MODEL="$("$SCRIPT_DIR/../fleet/agents-config.sh" get "$AGENT" model 2>/dev/null)"
[ -n "$HARNESS" ] || { printf 'error: unknown agent %s\nhelp: bin/fleet/agents-config.sh show\n' "$AGENT" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

run() {
  case "$HARNESS" in
    pi)       exec pi --print --model "$MODEL" "$TASK" ;;
    opencode) # `--agent` works when the agent is a primary (apply emits primaries)
              opencode run --agent "$AGENT" "$TASK" && exit 0
              exec opencode run -m "$MODEL" "$TASK" ;;
    claude)   exec claude -p ${MODEL:+--model "$MODEL"} "$TASK" ;;
    codex)    exec codex exec "$TASK" ;;
    gemini)   exec gemini -p "$TASK" ;;
    qwen)     exec qwen -p "$TASK" ;;
    hermes)   exec hermes "$TASK" ;;
    *)        printf 'error: harness not wired: %s\nhelp: pick pi|opencode|claude|codex|gemini|qwen|hermes in config/agents.yaml\n' "$HARNESS" >&2; exit 1 ;;
  esac
}

# The allow-list (2026-11-12): only the models this operator approved may run. Claude
# never takes another harness's `provider/model`, so the list's `defaults.claude` is
# used. A model the list refuses never launches (bin/model/model-allow.sh).
if [ "$HARNESS" = claude ]; then case "$MODEL" in */*|default) MODEL="" ;; esac; fi
ALLOW_OUT="$("$SCRIPT_DIR/../model/model-allow.sh" check "$MODEL" --harness "$HARNESS" --for "agent-run:$AGENT" 2>/dev/null)"
ALLOW_RC=$?
ALLOW_ROW="$(printf '%s\n' "$ALLOW_OUT" | python3 -c '
import json, sys
rows = sys.stdin.read().splitlines()
c = json.loads("[" + rows[1].strip() + "]") if len(rows) > 1 else ["", "", "", "refused", "", "the allow-list door gave no answer"]
print("\x1f".join([c[3], c[2], c[5]]))' 2>/dev/null)"
IFS=$'\x1f' read -r ALLOW_VERDICT ALLOW_MODEL ALLOW_WHY <<<"$ALLOW_ROW"
if [ "$ALLOW_RC" -ne 0 ] || [ "${ALLOW_VERDICT:-refused}" = refused ]; then
  printf 'refused: %s (%s on %s)\nhelp: bin/model/model-allow.sh list\n' "${ALLOW_WHY:-the allow-list refused this model}" "$AGENT" "$HARNESS" >&2
  exit 3
fi
[ -n "$ALLOW_MODEL" ] && MODEL="$ALLOW_MODEL"

have "$HARNESS" || { printf 'error: harness %s is not on PATH (%s)\n' "$HARNESS" "$AGENT" >&2; exit 1; }
printf 'agent-run[1]{agent,harness,model}:\n  "%s","%s","%s"\n' "$AGENT" "$HARNESS" "$MODEL" >&2
run
