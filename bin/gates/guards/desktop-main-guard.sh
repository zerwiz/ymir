#!/usr/bin/env bash
#
# cache: tree — this ward's verdict is a pure function of the tracked tree (no $YMIR_HOME read,
# no service, no clock, no network), so bin/gates/guards.sh may cache its PASS against the
# content it judged and an unchanged file is never re-scanned (plan 243 §3, part F). A ward
# that reads anything outside the tree must NOT carry this line: a cache that hides a real
# finding is the one thing this house does not ship.
# cache: tree
# desktop-main-guard — no launcher may point into a worktree.
#
# THE LAW (the Allfather, 2026-11-08): *"they all ned to point to main … the apps run time must be locked to
# main. otherwise they might break if the user are swithing threes"*. It broke exactly so: five entries
# pointed into `~/ymir/.yggdrasil/<errand>/…` and every desktop button opened a working copy that a session
# would later delete, or that had no node_modules at all.
#
# It judges the INSTALLED shelf (the machine's own state), not the tree, and it skips cleanly where there
# are no entries — a machine that installs nothing desktop-side is not a fault (RULES/25).
#
# Exit: 0 clean or skipped · 1 a launcher points into a worktree · 2 usage
set -uo pipefail
shelf="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
shopt -s nullglob
entries=("$shelf"/ymir-*.desktop "$shelf"/rodd.desktop)
shopt -u nullglob
if [ "${#entries[@]}" -eq 0 ]; then
  printf 'desktop-main-guard: no Ymir launcher entries installed — skipped (a skip is a pass)\n'
  exit 0
fi
bad=0
for f in "${entries[@]}"; do
  [ -r "$f" ] || continue
  exec_line="$(sed -n 's/^Exec=//p' "$f" | head -1)"
  case "$exec_line" in
    */.yggdrasil/*)
      bad=$((bad+1))
      printf 'desktop-main-guard: %s points into a WORKTREE\n  Exec=%s\n  fix: bash bin/host/omarchy-install.sh   (from the main tree)\n' \
        "$(basename "$f")" "$exec_line";;
  esac
done
if [ "$bad" -gt 0 ]; then
  printf 'desktop-main-guard refused: %s launcher(s) would break the moment that worktree is switched or deleted\n' "$bad" >&2
  exit 1
fi
printf 'desktop-main-guard: %s launcher(s), every one seated from a real tree\n' "${#entries[@]}"
