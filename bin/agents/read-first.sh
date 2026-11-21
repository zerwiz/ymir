#!/usr/bin/env bash
# read-first.sh — the "Read first" section of a brief: the house's own books for the paths the work touches.
#
# The Allfather, 2026-11-21: the coder and the judge were never told which skill, canonical doc and
# book own the code they were about to change. bin/records/where.sh already knows (one row per
# governed path); this door asks it for every path the task names, or touches, and writes the answer
# as a short section of PATHS — never pasted text — so a worker opens the book before the code.
#
#   read-first.sh --text <file>        paths named in a brief or task text (a path that exists in the tree)
#   read-first.sh --diff [<base>]      paths this branch changed against <base> (default origin/main)
#   read-first.sh --judge <path> …     the judge's list: the PR's changed paths + the compliance gate to run
#   read-first.sh <path> …             named paths
#
# Output: Markdown, on stdout; nothing at all when no path is mapped (a section with no rows teaches nothing).
# A path with no row in the subsystem map is named once at the foot, so the gap is visible.
set -u
case "${1-}" in -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
SELF="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
TREE="$(dirname "$(dirname "$SELF")")"
WHERE="$TREE/bin/records/where.sh"
JUDGE=0; PATHS=()
while [ $# -gt 0 ]; do case "$1" in
  --judge) JUDGE=1; shift ;;
  --text)
    f="${2-}"; shift 2
    [ -r "$f" ] || continue
    # the task's own section when the file has one (a brief's boilerplate names paths nobody is asked to touch);
    # candidate tokens: something/with/slashes or a file with a known extension, trimmed of punctuation
    while IFS= read -r tok; do
      tok="${tok%%[\`\"\'\),.:;]}"; tok="${tok##[\`\"\'\(]}"
      [ -n "$tok" ] && { [ -e "$TREE/$tok" ] && PATHS+=("$tok"); }
    done < <({ awk '/^# Task/{t=1;next} /^# (Delivery contract|Read first)/{t=0} t' "$f" | grep . >/dev/null && awk '/^# Task/{t=1;next} /^# (Delivery contract|Read first)/{t=0} t' "$f" || cat "$f"; } | grep -oE '[A-Za-z0-9_.@-]+(/[A-Za-z0-9_.@*-]+)+/?|[A-Za-z0-9_-]+\.(sh|py|ts|tsx|md|yaml|yml|json)' | sort -u | head -60)
    ;;
  --diff)
    base="origin/main"; case "${2-}" in ""|--*) ;; *) base="$2"; shift ;; esac; shift
    while IFS= read -r p; do [ -n "$p" ] && PATHS+=("$p"); done < <(git -C "$TREE" diff --name-only "$base"...HEAD 2>/dev/null)
    ;;
  *) PATHS+=("$1"); shift ;;
esac; done

rows=(); seen=" "; unmapped=()
for p in "${PATHS[@]+"${PATHS[@]}"}"; do
  out="$(bash "$WHERE" "${p%/}" 2>/dev/null)"; rc=$?
  row="$(printf '%s\n' "$out" | sed -n '2p')"
  if [ "$rc" -ne 0 ] || [ -z "$row" ] || printf '%s' "$row" | grep -q 'no row in'; then unmapped+=("$p"); continue; fi
  IFS=$'\x1f' read -r matches entry canonical books doors missing < <(printf '%s' "$row" | sed -E 's/^ *"//; s/"$//; s/","/\x1f/g')
  key="$entry|$canonical"
  case "$seen" in *" $key "*) continue ;; esac
  seen="$seen$key "
  rows+=("- \`$p\` → entry skill \`$entry\` · canonical doc \`$canonical\`${books:+ · books $books}${doors:+ · doors \`$doors\`}")
  [ "${#rows[@]}" -ge 12 ] && break
done

[ "${#rows[@]}" -gt 0 ] || [ "$JUDGE" -eq 1 ] || exit 0
printf '# Read first\n\n'
if [ "${#rows[@]}" -gt 0 ]; then
  printf 'The house keeps a book for the code this work touches. Open the entry skill, then the canonical doc, BEFORE you edit or judge (paths, not pasted text; `bin/records/where.sh <path>` answers for any other path):\n\n'
  printf '%s\n' "${rows[@]}"
else
  printf 'No path here is mapped to a book yet; `bin/records/where.sh <path>` answers for any path you touch.\n'
fi
if [ "${#unmapped[@]}" -gt 0 ]; then
  printf '\nNo book is mapped for: %s — name that gap in your report.\n' "$(printf '`%s` ' "${unmapped[@]:0:6}")"
fi
if [ "$JUDGE" -eq 1 ]; then
  printf '\nRun the house compliance gate on the PR head and put its output in your report: `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`\n'
fi
exit 0
