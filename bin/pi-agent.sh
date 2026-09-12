#!/usr/bin/env bash
# pi-agent.sh — run a Ymir agent on a LOCAL model with ITS OWN persona/mission
# (not Brokk's), loading only the skills it needs. Reusable for users.
#
#   bin/pi-agent.sh <agent> "<task>"
#   bin/pi-agent.sh hnoss "design a hero" --skill .agents/skills/hnoss-design
#   bin/pi-agent.sh sindri "fix the bug" -m qwen3.6-35b-q4_k_s
#
# It loads the agent's canonical profile body as the system prompt, disables the
# root AGENTS.md / global skills / Ymir persona, and adds the agent's own skill
# (if it has one) plus any --skill paths. Local models run one at a time — see
# bin/local-model-lock.sh.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROVIDER="${PI_LOCAL_PROVIDER:-llama-cpp}"
MODEL="${PI_LOCAL_MODEL:-frontend-design-expert-8b@q4_k_m}"
AGENT=""; TASK=""; SKILLS=()

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

[ $# -gt 0 ] || { printf 'error: usage: bin/pi-agent.sh <agent> "<task>"\n' >&2; exit 2; }
AGENT="$1"; shift
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--model) MODEL=${2-}; shift 2 ;;
    -p|--provider) PROVIDER=${2-}; shift 2 ;;
    --skill) SKILLS+=("${2-}"); shift 2 ;;
    *) TASK="$TASK${TASK:+ }$1"; shift ;;
  esac
done
[ -n "$TASK" ] || { printf 'error: %s needs a task\n' "$AGENT" >&2; exit 2; }

# 1. the agent's canonical profile (persona + mission) by `name:`.
PROFILE=""
for f in "$ROOT"/.agents/agents/*.md; do
  [ -e "$f" ] || continue
  grep -qx "name: $AGENT" "$f" && { PROFILE="$f"; break; }
done
[ -n "$PROFILE" ] || { printf 'error: no profile named %s\nhelp: bin/agents-config.sh show\n' "$AGENT" >&2; exit 1; }

# 2. persona = the profile body (everything after the frontmatter).
PERSONA="$(python3 - "$PROFILE" <<'PY'
import sys
t = open(sys.argv[1]).read()
parts = t.split("---")
print("---".join(parts[2:]).strip() if len(parts) >= 3 else t)
PY
)"

# 3. the agent's own skill, if it has one, plus any explicit --skill.
[ -f "$ROOT/.agents/skills/$AGENT/SKILL.md" ] && SKILLS+=("$ROOT/.agents/skills/$AGENT")

command -v pi >/dev/null 2>&1 || { printf 'error: pi is not on PATH\n' >&2; exit 1; }

args=(--print --no-context-files --no-skills --system-prompt "$PERSONA" --model "$PROVIDER/$MODEL")
for s in "${SKILLS[@]:-}"; do [ -n "$s" ] && args+=(--skill "$s"); done

printf 'pi-agent[1]{agent,provider,model,skills}:\n  "%s","%s","%s","%s"\n' \
  "$AGENT" "$PROVIDER" "$MODEL" "$(IFS=,; echo "${SKILLS[*]:-none}")" >&2
# Local inference is serialized per host (one model at a time by default).
exec "$SCRIPT_DIR/local-model-lock.sh" pi "${args[@]}" "$TASK"
