#!/usr/bin/env bash
# feature-inventory.sh — every feature the system CLAIMS, in one checklist.
#
# "Every single feature must work" is a hope until there is a list. This builds
# the list from the tree itself rather than from anyone's memory: every tool, job,
# skill, agent, app, workflow, service and registered project. It asserts nothing
# about whether they work — that is the verification pass, and it needs this
# inventory to exist first.
#
#   bin/feature-inventory.sh            # the inventory, as TOON
#   bin/feature-inventory.sh --counts   # just the tallies
#   bin/feature-inventory.sh --verify-plan   # the inventory as a checklist to fill in
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOARD="${YMIR_HOARD:-${YMIR_HOME:-$HOME/Documents/Ymir}/hodd}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
MODE="${1:-all}"

n_tools=$(find "$ROOT/bin" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' \) 2>/dev/null | wc -l | tr -d ' ')
n_jobs=$(ls "$ROOT"/bin/nornir-job-*.sh 2>/dev/null | wc -l | tr -d ' ')
n_skills=$(find -L "$ROOT/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
n_agents=$(ls "$ROOT"/.agents/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
n_workflows=$(ls "$ROOT"/.github/workflows/*.yml 2>/dev/null | wc -l | tr -d ' ')
n_apps=$(find "$ROOT/apps" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
n_migrations=$(ls "$ROOT"/.agents/migrations/*.sh 2>/dev/null | wc -l | tr -d ' ')
n_projects=0
[ -r "$HOARD/identity/projects.yaml" ] && n_projects=$(grep -c '^  - id:' "$HOARD/identity/projects.yaml" 2>/dev/null | tr -d ' ')

if [ "$MODE" = "--counts" ]; then
  printf 'features[8]{kind,count}:\n'
  printf '  "tools (bin/)",%s\n' "$n_tools"
  printf '  "nornir jobs",%s\n' "$n_jobs"
  printf '  "skills",%s\n' "$n_skills"
  printf '  "agents",%s\n' "$n_agents"
  printf '  "workflows (CI)",%s\n' "$n_workflows"
  printf '  "apps",%s\n' "$n_apps"
  printf '  "migrations",%s\n' "$n_migrations"
  printf '  "registered projects",%s\n' "$n_projects"
  exit 0
fi

# The checklist: one row per thing that must be proven.
printf 'inventory[8]{kind,count,how_proven}:\n'
printf '  "tools (bin/)",%s,"bash -n + --version/--help runs, exit 0"\n' "$n_tools"
printf '  "nornir jobs",%s,"one run each, --check or dry-run, writes as documented"\n' "$n_jobs"
printf '  "skills",%s,"its scripts run; its asset paths resolve (skillindex gate)"\n' "$n_skills"
printf '  "agents",%s,"bound into all five harnesses (harnesses gate) + a dispatch"\n' "$n_agents"
printf '  "workflows (CI)",%s,"YAML parses + the job runs green on the branch"\n' "$n_workflows"
printf '  "apps",%s,"builds, serves, wears its rune, installs its entry, opens in Electron"\n' "$n_apps"
printf '  "migrations",%s,"idempotent; re-run leaves the home unchanged"\n' "$n_migrations"
printf '  "registered projects",%s,"gh resolves the repo; PR ledger reports its PRs"\n' "$n_projects"

printf 'tools[%s]{tool}:\n' "$n_tools"
for f in "$ROOT"/bin/*; do
  [ -f "$f" ] || continue
  case "$f" in *.sh|*.py|*.js) printf '  "%s"\n' "$(basename "$f")" ;; esac
done

printf 'jobs[%s]{job}:\n' "$n_jobs"
for f in "$ROOT"/bin/nornir-job-*.sh; do [ -f "$f" ] && printf '  "%s"\n' "$(basename "$f")"; done

printf 'apps[%s]{app}:\n' "$n_apps"
for d in "$ROOT"/apps/*/; do [ -d "$d" ] && printf '  "%s"\n' "$(basename "$d")"; done

printf 'skills[%s]{skill,owner}:\n' "$n_skills"
grep -oE '^  "[a-z0-9-]+","[^"]*","[a-z]+"' "$ROOT/.agents/skills/README.md" 2>/dev/null | sed 's/^  //' || true
