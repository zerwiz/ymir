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
PROVIDER="${PI_LOCAL_PROVIDER:-}"
MODEL="${PI_LOCAL_MODEL:-}"
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

# Resolve provider + model from the hoard when env/flag did not name them: the
# figure's own model first, else the hoard default_model. No concrete id in-tree.
if [ -z "$PROVIDER" ] || [ -z "$MODEL" ]; then
  _am="$([ -x "$SCRIPT_DIR/agents-config.sh" ] && "$SCRIPT_DIR/agents-config.sh" get "$AGENT" model 2>/dev/null)"
  [ -n "$_am" ] || _am="$([ -x "$SCRIPT_DIR/agents-config.sh" ] && "$SCRIPT_DIR/agents-config.sh" default 2>/dev/null)"
  [ -n "$PROVIDER" ] || PROVIDER="${_am%%/*}"
  [ -n "$MODEL" ] || MODEL="${_am#*/}"
fi
[ -n "$PROVIDER" ] && [ -n "$MODEL" ] || {
  printf 'error: no model resolved for %s — set -m/-p or config/agents.yaml in your hoard\n' "$AGENT" >&2
  exit 2
}

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

# 3. the agent's own skill, if it has one (folder is now figure-function,
#    e.g. hnoss-design), plus any explicit --skill.
for sk in "$ROOT/.agents/skills/$AGENT" "$ROOT"/.agents/skills/"$AGENT"-*; do
  [ -f "$sk/SKILL.md" ] && { SKILLS+=("$sk"); break; }
done

command -v pi >/dev/null 2>&1 || { printf 'error: pi is not on PATH\n' >&2; exit 1; }

args=(--print --no-context-files --no-skills --system-prompt "$PERSONA" --model "$PROVIDER/$MODEL")
for s in "${SKILLS[@]:-}"; do [ -n "$s" ] && args+=(--skill "$s"); done

printf 'pi-agent[1]{agent,provider,model,skills}:\n  "%s","%s","%s","%s"\n' \
  "$AGENT" "$PROVIDER" "$MODEL" "$(IFS=,; echo "${SKILLS[*]:-none}")" >&2
# Local inference is serialized per host (one model at a time by default).
exec "$SCRIPT_DIR/local-model-lock.sh" pi "${args[@]}" "$TASK"
