#!/usr/bin/env bash
# skill-find.sh — find the skill you need, without loading any of them.
#
# THE DESIGN, and it matters: a session must NOT load every skill. That is how
# a context fills with instructions that do not apply, and an agent that reads
# forty skills acts like it read none. So nothing is preloaded. Instead:
#
#   you ask a question in words  ->  this greps the descriptions  ->  you get
#   the one or three paths, and you read those.
#
# Three shelves, and the order is the point:
#   1. .agents/skills/          ships with the repo and the npm package
#   2. .agents/skills-local/    THIS MACHINE ONLY - never published, never cloned
#   3. the home shelf            the Allfather's own project craft (ymirhome)
#   4. ~/.pi/agent/skills/      yours, harness-wide, across projects
#
# A shipped skill always wins a name collision on purpose: the project's craft
# must be identical on every machine, or two developers get two answers.
#
# Usage:
#   bin/skill-find.sh deploy              # by word
#   bin/skill-find.sh "how do I make a course"
#   bin/skill-find.sh --list              # every skill and its one-line purpose
#   bin/skill-find.sh --where <name>      # the exact path of one skill
#   bin/skill-find.sh --check             # duplicates, missing files, orphans
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIPS="$ROOT/.agents/skills"
LOCALS="$ROOT/.agents/skills-local"
PISKILLS="$HOME/.pi/agent/skills"
# The Allfather's OWN shelf, in the private home. This is where the skills for
# their projects and their other work live - aigf, the fleet, anything that is
# about their business rather than about Ymir.
HOMESKILLS="$HOME/Documents/ymirhome/.agents/skills"

BOLD=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; OFF=$'\033[0m'

# The description is the only thing a finder can search, so it must exist and it
# must be one line. A skill with no description is a skill nobody can find.
describe() {
  local file="$1"
  # the front matter's description, folded onto one line
  awk 'BEGIN{in_fm=0} /^---$/{in_fm=!in_fm; next} in_fm && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$file" 2>/dev/null \
    | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

name_of() {
  awk 'BEGIN{in_fm=0} /^---$/{in_fm=!in_fm; next} in_fm && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$1" 2>/dev/null
}

where_of() {
  local want="$1"
  for shelf in "$SHIPS" "$LOCALS" "$HOMESKILLS" "$PISKILLS"; do
    [ -d "$shelf" ] || continue
    for f in "$shelf"/*/SKILL.md; do
      [ -f "$f" ] || continue
      [ "$(name_of "$f")" = "$want" ] && { echo "$f"; return 0; }
      [ "$(basename "$(dirname "$f")")" = "$want" ] && { echo "$f"; return 0; }
    done
  done
  return 1
}

# --list
if [ "${1:-}" = "--list" ]; then
  for shelf in "$SHIPS" "$LOCALS" "$PISKILLS"; do
    [ -d "$shelf" ] || continue
    case "$shelf" in
      "$SHIPS")     label="ships  " ;;
      "$LOCALS")   label="local  " ;;
      *)           label="yours  " ;;
    esac
    for f in "$shelf"/*/SKILL.md; do
      [ -f "$f" ] || continue
      d="$(describe "$f")"
      [ -n "$d" ] || d="(NO DESCRIPTION - unfindable; run --check)"
      printf '%s %s %-28s %s%s\n' "${DIM}" "$label" "$(basename "$(dirname "$f")")" "$d" "$OFF"
    done
  done
  exit 0
fi

# --where <name>
if [ "${1:-}" = "--where" ]; then
  p="$(where_of "${2:-}")" && { echo "$p"; exit 0; }
  printf '%sno skill named %s in any of the three shelves%s\n' "$RED" "${2:-}" "$OFF" >&2
  exit 1
fi

# --check: the health of the shelves
if [ "${1:-}" = "--check" ]; then
  fail=0
  declare -A seen=()
  for shelf in "$SHIPS" "$LOCALS" "$HOMESKILLS" "$PISKILLS"; do
    [ -d "$shelf" ] || continue
    for f in "$shelf"/*/SKILL.md; do
      [ -f "$f" ] || continue
      dir="$(basename "$(dirname "$f")")"
      n="$(name_of "$f")"; d="$(describe "$f")"
      [ -n "$d" ] || { printf '%sno description — unfindable: %s%s\n' "$YEL" "$f" "$OFF"; fail=1; }
      [ -n "$n" ] || { printf '%sno name in front matter: %s%s\n' "$YEL" "$f" "$OFF"; fail=1; }
      if [ -n "${seen[$n]:-}" ] && [ "${seen[$n]}" != "$f" ]; then
        printf '%sduplicate skill name %s — %s and %s%s\n' "$RED" "$n" "${seen[$n]}" "$f" "$OFF"; fail=1
      fi
      seen[$n]="$f"
    done
  done
  [ "$fail" = 0 ] && printf '%sall shelves are findable%s\n' "$GRN" "$OFF"
  exit $fail
fi

# the default: search the descriptions
QUERY="${*:-}"
[ -z "$QUERY" ] && { echo "usage: bin/skill-find.sh <words> | --list | --where <name> | --check" >&2; exit 2; }

HITS=0
for shelf in "$SHIPS" "$LOCALS" "$HOMESKILLS" "$PISKILLS"; do
  [ -d "$shelf" ] || continue
  case "$shelf" in
    "$SHIPS") label="ships" ;;
    "$LOCALS") label="LOCAL — this machine only" ;;
    "$HOMESKILLS") label="home — the Allfather's own craft" ;;
    *) label="yours" ;;
  esac
  for f in "$shelf"/*/SKILL.md; do
    [ -f "$f" ] || continue
    hay="$(describe "$f") $(name_of "$f") $(basename "$(dirname "$f")")"
    if printf '%s' "$hay" | grep -qi -- "$QUERY"; then
      HITS=$((HITS+1))
      printf '%s[%s]%s %s\n' "$BOLD" "$label" "$OFF" "$f"
      printf '        %s%s%s\n' "$DIM" "$(describe "$f")" "$OFF"
    fi
  done
done

[ "$HITS" = 0 ] && printf '%sno skill mentions "%s" — report the gap, do not improvise%s\n' "$YEL" "$QUERY" "$OFF"
printf '\n%s%d match(es). Read the one you need; do not read them all.%s\n' "$DIM" "$HITS" "$OFF"
