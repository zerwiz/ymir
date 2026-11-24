#!/usr/bin/env bash
# weave-needed.sh — does this commit touch anything the woven registers are built from?
#
# WHY (plan 369 item 9, measured 2026-11-24): the pre-commit hook ran bin/records/weave.sh on EVERY
# commit, and weave.sh rebuilds the inventory (bin/gates/inventory.sh, 115 s) and the capabilities
# register (bin/gates/capabilities.sh, 295 s) from the whole tree. A one-line fix note took 8 to 15
# minutes to commit. The registers are a function of a few inputs, so the hook now asks this door
# first and weaves only when one of them is staged.
#
# What the registers read (bin/gates/capabilities.sh, bin/gates/inventory.sh, bin/records/weave-features.sh):
#   - the SET of doors: a file added, deleted, renamed or copied under bin/ src/ymir_runtime/
#     .pi/shared/extensions/ .agents/skills/ .agents/tests/
#   - a door's HEADER: "the job" is the first comment in lines 2-12, so a modified bin/ or
#     src/ymir_runtime/ file whose staged diff reaches line 12 or above
#   - what NAMES or TESTS a door: AGENTS.md, a skill's SKILL.md or assets/*.md, any tests/ file
#   - the registers' own inputs and writers: bin/gates/registers/, .agents/assets/agents/capabilities*,
#     .agents/backend/, docs/features/, the weavers themselves
# Anything else (a door's body, a fix note, a doc, an app) cannot move a register row. The weave ward
# (bin/gates/guards/weave-guard.sh) and CI still judge drift, so a miss here is caught, never shipped.
#
#   weave-needed.sh            # exit 0 = weave, 1 = skip; prints the reason on one line
#   weave-needed.sh --list F   # judge a name-status list (git diff --name-status format) from file F
#
# Overrides: YMIR_WEAVE=1 always weaves · YMIR_SKIP_WEAVE=1 never weaves.
# Exit: 0 weave · 1 skip · 2 usage.
set -uo pipefail
HEADER_LINES="${YMIR_WEAVE_HEADER_LINES:-12}"

[ "${YMIR_WEAVE:-}" = 1 ] && { printf 'weave-needed: yes — YMIR_WEAVE=1\n'; exit 0; }
[ "${YMIR_SKIP_WEAVE:-}" = 1 ] && { printf 'weave-needed: no — YMIR_SKIP_WEAVE=1\n'; exit 1; }

list=""
case "${1:-}" in
  --list) [ -r "${2:-}" ] || { printf 'error: --list needs a readable file\n' >&2; exit 2; }; list="$(cat "$2")" ;;
  "") list="$(git diff --cached --name-status -M 2>/dev/null)" ;;
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'error: unknown argument %s\nhelp: weave-needed.sh [--list <file>]\n' "$1" >&2; exit 2 ;;
esac

header_touched() {  # <path> — does the staged diff of this file reach the header lines?
  [ -n "${YMIR_WEAVE_TEST_HEADER:-}" ] && { case " $YMIR_WEAVE_TEST_HEADER " in *" $1 "*) return 0 ;; esac; return 1; }
  git diff --cached -U0 -- "$1" 2>/dev/null \
    | sed -nE 's/^@@ -([0-9]+)(,[0-9]+)? \+([0-9]+)(,[0-9]+)? @@.*/\1 \3/p' \
    | awk -v h="$HEADER_LINES" '$1 <= h || $2 <= h { found=1 } END { exit found ? 0 : 1 }'
}

input_path() {  # <path> — a file whose content any register reads
  case "$1" in
    AGENTS.md|.agents/skills/*/SKILL.md|.agents/skills/*/assets/*.md) return 0 ;;
    */tests/*|tests/*|.agents/tests/*) return 0 ;;
    bin/gates/registers/*|.agents/assets/agents/capabilities*|.agents/backend/*|docs/features/*) return 0 ;;
    bin/gates/inventory.sh|bin/gates/capabilities.sh|bin/records/weave.sh|bin/records/weave-features.sh) return 0 ;;
  esac
  return 1
}

door_tree() {  # <path> — a path whose presence is a door or a counted surface
  case "$1" in
    bin/*|src/ymir_runtime/*|.pi/shared/extensions/*|.agents/skills/*|.agents/tests/*) return 0 ;;
  esac
  return 1
}

while IFS=$'\t' read -r st a b; do
  [ -n "${st:-}" ] || continue
  path="${b:-$a}"
  case "$st" in
    A*|D*|R*|C*)
      if door_tree "$a" || { [ -n "${b:-}" ] && door_tree "$b"; }; then
        printf 'weave-needed: yes — %s %s changes the set of doors\n' "${st:0:1}" "$path"; exit 0
      fi ;;
  esac
  if input_path "$path"; then
    printf 'weave-needed: yes — %s is read by a register\n' "$path"; exit 0
  fi
  case "$path" in
    bin/*|src/ymir_runtime/*)
      if header_touched "$path"; then
        printf 'weave-needed: yes — the header of %s changed (lines 1-%s)\n' "$path" "$HEADER_LINES"; exit 0
      fi ;;
  esac
done <<<"$list"

printf 'weave-needed: no — nothing staged is read by a register (YMIR_WEAVE=1 forces a weave)\n'
exit 1
