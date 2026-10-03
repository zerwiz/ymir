#!/usr/bin/env bash
# home-index-check.sh — every shelf in the home has an index, and the index is honest.
#
# WHY (2026-10-01): *"so the reference.mds and read_mis.mds are functional in the home"* and
# *"we need to have a way so we know which information and documents are fresh and which are
# older"*. A shelf whose README is missing cannot be navigated, and a README that lists
# fewer files than the shelf holds is **worse than none** — it is a confident, wrong map. That
# is the same failure as an authored register, and it is the reason this door checks the
# VAULT's own indexes the way `bin/inventory.sh --check` checks the repo's.
#
#   bin/home-index-check.sh            # report
#   bin/home-index-check.sh --strict   # non-zero when any shelf has no index or a stale one
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bin/hoard-lib.sh
. "$ROOT/bin/hoard-lib.sh" 2>/dev/null || true
H=""
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root H
# No literal fallback: if the resolver cannot name a home, say so. A door that
# guesses where the vault lives is the same fault as a graded-but-unmeasured doc.
if [ -z "$H" ] && [ -z "${YMIR_HOME:-}" ]; then
  echo "home-index-check: no home resolved (set \$YMIR_HOME) — nothing touched" >&2
  exit 0
fi
[ -n "$H" ] || H="$YMIR_HOME"
[ -d "$H" ] || { echo "home-index-check: no home at $H"; exit 0; }

STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

no_index=0; stale=0; shelves=0
report() { printf '  %-52s %s\n' "$1" "$2"; }

printf 'home_index[3]{shelves,no_index,stale}:\n'
check_shelf() {  # <dir>
  local d=$1 name files listed
  [ -d "$d" ] || return 0
  # a shelf is a directory holding documents, not a machine shelf
  files=$(find "$d" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$files" -gt 0 ] || return 0
  shelves=$((shelves + 1))
  name="${d#$H/}"
  if [ ! -f "$d/README.md" ] && [ ! -f "$d/INDEX.md" ]; then
    report "$name" "NO INDEX ($files docs) — a shelf nobody can navigate"
    no_index=$((no_index + 1))
    return 0
  fi
  local idx="$d/README.md"; [ -f "$idx" ] || idx="$d/INDEX.md"
  # honest means: the index NAMES most of what is there. A heuristic, and it says so:
  # it counts rows/names in the index and compares against the shelf.
  listed=$(grep -cE '\.(md|mp4|tgz|sh|ts|json)\b|\|.*\|' "$idx" 2>/dev/null || echo 0)
  if [ "${listed:-0}" -lt $(( files / 2 )) ]; then
    report "$name" "STALE INDEX ($listed named of $files docs) — a confident, wrong map"
    stale=$((stale + 1))
  else
    report "$name" "ok ($files docs, $listed named)"
  fi
}

for d in "$H"/hodd/*/ ; do check_shelf "${d%/}"; done
# the REPO's asset shelf obeys the same law: naming.md and registry.md are how an agent
# finds what a thing is called, and a shelf of 7 with no index is invisible by accident.
check_shelf "$ROOT/.agents/assets"
check_shelf "$ROOT/.agents/assets/agents"
for d in "$H"/svartalfaheim/*/projects/*/ ; do check_shelf "${d%/}"; done
for d in "$H"/svartalfaheim/*/projects/*/*/ ; do check_shelf "${d%/}"; done

printf '  "%s","%s","%s"\n' "$shelves" "$no_index" "$stale"
if [ "$no_index" -gt 0 ] || [ "$stale" -gt 0 ]; then
  printf 'home-index-check: %s shelf/shelves without a usable index — features land in the wrong place when a shelf cannot be navigated\n' "$(( no_index + stale ))" >&2
  [ "$STRICT" = 1 ] && exit 1
fi
exit 0