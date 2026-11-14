#!/usr/bin/env bash
# hearth-guard.sh — one capability, one implementation: a second copy is a fault, and two
# paths that differ only by case are one path on macOS and Windows.
#
# Rule: RULES/13 (one home; two load paths seats nobody) and RULES/17 (no dead code — the
# dead half is `dead-code-guard.sh`'s, and this ward does not repeat it).
#
# WHY (plan 283, 2026-11-13). The Allfather, for the third time: "sessrumnir are having
# problem with the ember again … we have old plans of this and fixed it several of times."
# Measured: the app carried THREE hearths — `ember-background.tsx` (live), a dead
# `EmberBackground.tsx` twin one keystroke away (a dash and a capital), and a dark copy of
# `midgard/design-system/ember.js` — so every repair landed in a file the others did not
# read, and a `grep` matched the dead twin first. Separately, two paths that differ ONLY by
# case are their own hazard: fine on Linux, ONE file on a macOS or a Windows checkout. No
# such pair exists in the tree tonight; this ward keeps it that way.
#
#   hearth-guard.sh check      # the ward (used by bin/gates/guards.sh)
#   hearth-guard.sh --list     # what it scans
#
# Exit: 0 clean · 1 findings · 3 unavailable (not a git checkout).
#
# ── WHAT THIS CANNOT SEE, stated so nobody assumes it does ────────────────────
#   · two implementations that are deliberately named differently (declared below, by name)
#   · a copy made at BUILD time, inside out/ or dist/ (that is a deploy, not a source)
#   · an UNTRACKED copy — it is not part of a push and so not a shipped fault; it is caught
#     the moment it is staged, which is the first moment it can reach another machine
# The ward judges the SOURCE tree and the TRACKED paths, which is where tonight's fault lived.
set -u

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}
ROOT="$(_root)"
cd "$ROOT" 2>/dev/null || { printf 'unavailable: no tree at %s\n' "$ROOT" >&2; exit 3; }
command -v git >/dev/null 2>&1 || { printf 'unavailable: git is absent\n' >&2; exit 3; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'unavailable: %s is not a git checkout\n' "$ROOT" >&2; exit 3; }

case "${1-check}" in
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --list)
    printf 'hearth-guard scans:\n'
    printf '  every tracked path            (two that differ only by case)\n'
    printf '  apps/*/**                      (one hearth component per app)\n'
    exit 0 ;;
  check|"") ;;
  *) printf 'error: unknown flag %s\nhelp: hearth-guard.sh [check|--list]\n' "${1-}" >&2; exit 2 ;;
esac

files="$(git ls-files)" || exit 3
findings=0
checked=0

# ── 1. two paths that are one path on a case-insensitive filesystem ──────────
# The delete on 2026-11-13 was the only one in the tree; this keeps it that way.
while IFS= read -r pair; do
  [ -n "$pair" ] || continue
  findings=$((findings+1))
  printf '  "%s","ONE PATH ON macOS/WINDOWS","these differ only by case — a checkout there compiles one and loses the other\n' "$pair"
done < <(printf '%s\n' "$files" | awk '{ print tolower($0) "\t" $0 }' | sort -k1,1 \
  | awk -F'\t' '!($1 in first) { first[$1]=$2 } ($1 in first) && first[$1] != $2 { print first[$1] " | " $2 }')

# ── 2. one hearth per app ───────────────────────────────────────────────────
# A capability named here is a capability with ONE implementation per app. The fire is the
# first entry; a second one gets its name added to this list only with a reason in the ward.
hearth_pattern='(^|/)(ember|ember-background|EmberBackground)\.(tsx)$'
while IFS= read -r app; do
  [ -n "$app" ] || continue
  n="$(printf '%s\n' "$files" | grep -E "^apps/$app/" | grep -icE "$hearth_pattern")"
  checked=$((checked+1))
  if [ "${n:-0}" -gt 1 ]; then
    findings=$((findings+1))
    printf '  "apps/%s","TWO HEARTHS","%s implementations — keep ONE file; the rest is a copy every repair misses"\n' \
      "$app" "$n"
    printf '%s\n' "$files" | grep -E "^apps/$app/" | grep -iE "$hearth_pattern" | sed 's/^/      /'
  fi
done < <(printf '%s\n' "$files" | sed -n 's|^apps/\([^/]*\)/.*|\1|p' | sort -u)

printf 'hearth-guard[2]{apps_checked,findings}:\n'
printf '  "%s","%s"\n' "$checked" "$findings"
if [ "$findings" -eq 0 ]; then
  printf 'hearth-guard: one capability, one implementation — clean\n'
  exit 0
fi
printf 'hearth-guard: FAIL (%s) — a second copy of a thing is not a feature; delete the copy, or name who reads it (RULES/16)\n' "$findings"
exit 1
