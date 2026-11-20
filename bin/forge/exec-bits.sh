#!/usr/bin/env bash
# exec-bits.sh — a new door leaves the errand executable, or the errand says so before the push.
#
# WHY (plan 339.1, 2026-11-20). One push on that day was refused, after minutes of wards, because a
# new door (`bin/boards/cardlib.py`) was committed without its executable bit — rules-compliance R4
# (RULES/12, RULES/23). The fault is mechanical, so the mend is too: every errand template runs this
# before its final commit, and the bit is set in the INDEX (`git update-index --chmod=+x`), which is
# what a clone receives — a `chmod` on the working tree alone is lost on the way out.
#
# A door is a file the range ADDS under bin/, systems/, tools/ or scripts/ ending in .sh or .py whose
# first line is a shebang — the same set R4 judges. A library sourced by others keeps no shebang and
# is not touched.
#
# Usage:
#   exec-bits.sh [--base <ref>]          # name the new doors whose index mode is not 100755
#   exec-bits.sh --fix [--base <ref>]    # set the bit in the index and the working tree
#
# Exit: 0 every new door is executable (or was just fixed) · 1 a door lacks the bit · 2 usage.
set -u
BASE=""; FIX=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1 ;;
    --base) BASE="${2:?--base needs a ref}"; shift ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: exec-bits.sh [--fix] [--base REF]\n' "$1" >&2; exit 2 ;;
  esac
  shift
done
TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || { printf 'error: not a git checkout\n' >&2; exit 2; }
cd "$TOP" || exit 2
if [ -z "$BASE" ]; then
  for b in origin/main origin/master main; do git rev-parse -q --verify "$b" >/dev/null 2>&1 && { BASE="$b"; break; }; done
fi
[ -n "$BASE" ] || { printf 'exec_bits[1]{base,result}:\n  "none","skip — no base ref"\n'; exit 0; }
MB="$(git merge-base "$BASE" HEAD 2>/dev/null || printf '%s' "$BASE")"

# what the range adds (committed), plus what is staged to be added next
mapfile -t added < <({ git diff --name-only --diff-filter=A "$MB" HEAD; git diff --cached --name-only --diff-filter=A; } | sort -u)
bad=(); fixed=()
for f in "${added[@]}"; do
  case "$f" in bin/*.sh|systems/*.sh|tools/*.sh|scripts/*.sh|bin/*.py|systems/*.py|tools/*.py) ;; *) continue ;; esac
  [ -f "$f" ] || continue
  head -1 "$f" | grep -qE '^#!' || continue
  mode="$(git ls-files -s -- "$f" | awk '{print $1}')"
  [ "$mode" = 100755 ] && [ -x "$f" ] && continue
  if [ "$FIX" = 1 ]; then
    chmod +x "$f" && git update-index --chmod=+x -- "$f" && fixed+=("$f") || bad+=("$f")
  else
    bad+=("$f")
  fi
done
printf 'exec_bits[%s]{door,state}:\n' "$(( ${#bad[@]} + ${#fixed[@]} ))"
for f in "${fixed[@]}"; do printf '  "%s","fixed — staged as 100755; commit it"\n' "$f"; done
for f in "${bad[@]}"; do printf '  "%s","NOT executable"\n' "$f"; done
if [ "${#bad[@]}" -gt 0 ]; then
  printf 'help: bin/forge/exec-bits.sh --fix   (sets the bit in the index, which is what a push carries)\n' >&2
  exit 1
fi
exit 0
