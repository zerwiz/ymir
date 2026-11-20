#!/usr/bin/env bash
# init.sh — put the collaboration shelf into a repository, or check the one it has.
#
#   init.sh <repo> [--from NAME] [--check] [--no-run]
#
# The shelf is four files and a check, and it is the same in every project:
#
#   handoff/README.md     the law: what the baton is, when it is written
#   handoff/TEMPLATE.md   the seven sections and the four header fields
#   handoff/CURRENT.md    the live baton, filled with today's branch and commit
#   handoff/log/          every past baton, append-only
#   handoff/check.sh      the check (check.py beside it), wired into the project's gate
#
# It never overwrites: a repository that already has a baton is checked, not rewritten. The check
# prefers the project's own checker (an Elixir mix task, a node script) and falls back to the shelf's.
#
# Exit: 0 installed/clean · 1 a check failed or the shelf is missing · 2 usage.
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$_d/templates"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

repo="" from="brokk" check=0 run=1
while [ $# -gt 0 ]; do
  case "$1" in
    --from) from="${2-}"; shift 2 ;;
    --check) check=1; shift ;;
    --no-run) run=0; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'init: unknown option %s\n' "$1" >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done
[ -n "$repo" ] || { usage; exit 2; }
[ -d "$repo" ] || { printf 'init: no such repository: %s\n' "$repo" >&2; exit 1; }
repo="$(cd "$repo" && pwd)"

# ---- the checker this project already has ------------------------------------------------------
detect_checker() {
  if [ -x "$repo/handoff/check.sh" ]; then printf 'handoff/check.sh'; return 0; fi
  if [ -f "$repo/mix.exs" ] && grep -rqs "Ct.Handoff" "$repo/apps"/*/lib/mix/tasks 2>/dev/null; then
    printf 'mix ct.handoff'; return 0
  fi
  if [ -f "$repo/mix.exs" ] && grep -rqs "Handoff" "$repo/lib/mix/tasks" 2>/dev/null; then
    printf 'mix handoff'; return 0
  fi
  if [ -f "$repo/package.json" ] && grep -qs '"handoff"' "$repo/package.json"; then
    printf 'npm run handoff'; return 0
  fi
  return 1
}

run_checker() {
  local checker="$1"
  case "$checker" in
    "handoff/check.sh") ( cd "$repo" && ./handoff/check.sh --check ) ;;
    "mix ct.handoff")   ( cd "$repo" && mix ct.handoff --check ) ;;
    "mix handoff")      ( cd "$repo" && mix handoff --check ) ;;
    "npm run handoff")  ( cd "$repo" && npm run handoff -- --check ) ;;
    *) return 1 ;;
  esac
}

if [ -f "$repo/handoff/CURRENT.md" ] || [ "$check" = 1 ]; then
  if checker="$(detect_checker)"; then
    printf 'collab[1]{field,value}:\n'
    printf '  "repo","%s"\n' "$repo"
    printf '  "checker","%s"\n' "$checker"
    if [ "$run" = 1 ]; then
      if run_checker "$checker"; then printf '  "state","clean"\n'; exit 0; fi
      printf '  "state","failed"\n' >&2; exit 1
    fi
    printf '  "state","not run (--no-run)"\n'; exit 0
  fi
  printf 'collab[2]{field,value}:\n'
  printf '  "repo","%s"\n' "$repo"
  printf '  "checker","none — a baton with no check is a document, not a gate"\n'
  exit 1
fi

# ---- install ----------------------------------------------------------------------------------
for existing in handoff/README.md handoff/TEMPLATE.md handoff/check.py handoff/check.sh handoff/CURRENT.md; do
  [ -e "$repo/$existing" ] && { printf 'init: %s already exists — refusing to overwrite\n' "$existing" >&2; exit 1; }
done

mkdir -p "$repo/handoff/log"
cp "$TPL/handoff-README.md"        "$repo/handoff/README.md"
cp "$TPL/handoff-TEMPLATE.md"      "$repo/handoff/TEMPLATE.md"
cp "$TPL/handoff-check.py"         "$repo/handoff/check.py"
cp "$TPL/handoff-check-wrapper.sh" "$repo/handoff/check.sh"
chmod +x "$repo/handoff/check.py" "$repo/handoff/check.sh"

stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
date_day="$(date -u +%Y-%m-%d)"
branch="unknown"; sha="unknown"
if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  sha="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then branch="unknown"; fi
  if [ -z "$sha" ]; then sha="unknown"; fi
fi
body="$(sed -e "s|<from> → <to>|$from → the next hand|" \
            -e "s|<ISO date>|$stamp|" \
            -e "s|<branch>|$branch|" \
            -e "s|<sha>|$sha|" "$repo/handoff/TEMPLATE.md")"
printf '%s\n' "$body" > "$repo/handoff/CURRENT.md"
printf '%s\n' "$body" > "$repo/handoff/log/$date_day-$from.md"

printf 'collab[5]{field,value}:\n'
printf '  "repo","%s"\n' "$repo"
printf '  "shelf","handoff/ — README · TEMPLATE · CURRENT · log/ · check.sh"\n'
printf '  "baton","%s\n' "handoff/log/$date_day-$from.md"
printf '  "branch","%s at %s"\n' "$branch" "$sha"
printf '  "next","fill the seven sections, then wire the check into the gate:"\n'

if [ -f "$repo/mix.exs" ]; then
  printf '  "wire","add \\"handoff/check.sh --check\\" to the precommit alias in mix.exs"\n'
elif [ -f "$repo/package.json" ]; then
  printf '  "wire","add \\"handoff\\": \\"handoff/check.sh --check\\" to package.json scripts, and call it from CI"\n'
else
  printf '  "wire","add handoff/check.sh --check to the CI job that must pass before a merge"\n'
fi
