#!/usr/bin/env bash
# ci-verify.sh — what CI must prove, in one command, for BOTH hosts.
#
# GitHub Actions and Forgejo Actions are two doors to the same room, so neither holds a
# copy of the checks: both call THIS. A workflow that re-listed the steps would be a second
# place for them to drift, which is the failure this whole repository is being taught to stop.
#
# THE GATE LIST IS A DIRECTORY (plan 295, fix S1; 2026-11-14). Every gate is ONE file under
# `bin/gates/checks.d/<NNNN>-<name>.sh`, read here in C order, so two branches that each add a
# gate add two different files and merge without a conflict. Before this, every branch appended
# its gate line to this one file, so every open pull request conflicted with every other and
# fourteen sound PRs could not merge. **To add a gate, add a file — never edit this file.**
# The number is zero-padded on purpose: C order is then NUMERIC order, so a gate added at 0335
# runs between 0330 and 0340 without anyone editing anything. The how-to:
# docs/features/adding-a-gate.md
#
# Usage:
#   ci-verify.sh            # run every gate CI owes
#   ci-verify.sh --fast     # skip the heavy one (the real npm install)
#
# Environment:
#   YMIR_GATE_CHECK_DIR   the gate directory to read (default bin/gates/checks.d). A test
#                         plants a directory of gates here; production never sets it.
#   YMIR_CI_VERDICT       where the failing gates are written (default $TMPDIR/ymir-ci-verdict.txt)
#
# Exit: 0 everything proved · 1 a gate failed · 2 usage or an unreadable gate list.
set -u

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
cd "$ROOT" || exit 2

FAST=0
case "${1-}" in
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --fast)    FAST=1 ;;
  "")        ;;
  *)         printf 'error: unknown flag %s\nhelp: ci-verify.sh [--fast]\n' "${1-}" >&2; exit 2 ;;
esac

fail=0
printf 'ci_verify[4]{gate,status,detail}:\n'

# THE VERDICT, IN A FILE (plan 243 §3, part E). When CI is red on main, the sweep must be able
# to name the ward and the commit that broke it without re-running a five-minute suite over the
# failure. So every failing gate is written here as `gate<TAB>what`, and the ward gate's own
# table is kept beside it (`<verdict>.wards`) — bin/gates/main-red.sh reads the log (one door for a red main, plan 243 part E).
VERDICT="${YMIR_CI_VERDICT:-${TMPDIR:-/tmp}/ymir-ci-verdict.txt}"
: >"$VERDICT" 2>/dev/null || VERDICT=/dev/null

gate() {  # <name> <description> <command...>
  local name="$1" what="$2"; shift 2
  local out; out="$( "$@" 2>&1 )" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  "%s","PASS","%s"\n' "$name" "$what"
  else
    printf '%s\t%s\n' "$name" "$what" >>"$VERDICT" 2>/dev/null || true
    printf '  "%s","FAIL","%s"\n' "$name" "$what"
    # The failing gate's own tail — the single-line swallow hid WHICH check
    # died inside (e.g. pr-pretest's hull/sandbox/app-boot rows). Print the
    # last 12 lines so CI tells us the actual failing step.
    printf '%s\n' "$out" | grep -vE '^[[:space:]]*$' | tail -12 | sed 's/^/    /'
    fail=1
  fi
  return 0
}

# SEAT THE MERGE DRIVER FIRST. `features-guard` requires `merge.regenerate.driver` to exist in the
# clone's git config — a fresh checkout (every CI run) has it unset, so the ward failed on correct code
# with "the merge driver is not seated", which is the same false red this house keeps paying for.
# The install seats it on a real seat; CI seats it here, once, before the wards.
if [ -x "$ROOT/bin/records/weave-features.sh" ]; then
  "$ROOT/bin/records/weave-features.sh" --install >/dev/null 2>&1 || \
    printf '  "%s","NOTE","%s"\n' weave-driver "the merge driver could not be seated in this clone"
fi

# ── the gates, in C order, one file each ────────────────────────────────────
# C order is not a detail: the rows print in the order the files sort, and two hands reading one
# run must see one order. The names are zero-padded so that order is the number on the file. A
# file may define a helper (0000-lib.sh is sourced first) and calls `gate` once — or, for a gate
# that can only answer in some checkouts, prints its own honest SKIP row.
CHECKS_DIR="${YMIR_GATE_CHECK_DIR:-$ROOT/bin/gates/checks.d}"
if [ ! -d "$CHECKS_DIR" ]; then
  printf 'ci-verify: no gate directory at %s — the gate list is unreadable\nhelp: every gate is one file under bin/gates/checks.d/\n' "$CHECKS_DIR" >&2
  exit 2
fi

GATE_FILES=()
while IFS= read -r f; do GATE_FILES+=("$f"); done < <(LC_ALL=C find "$CHECKS_DIR" -maxdepth 1 -type f -name '*.sh' | LC_ALL=C sort)

# AN EMPTY LIST IS NOT A GREEN. A driver that runs no gate would print a bare header and exit 0,
# which is the false green this house has paid for before: the list vanishes (a bad checkout, a
# rename, a filter) and nothing says so. So it refuses, loudly, non-zero.
if [ "${#GATE_FILES[@]}" -eq 0 ]; then
  printf 'ci-verify: the gate directory %s holds no gate — nothing would be proved\nhelp: every gate is one file under bin/gates/checks.d/\n' "$CHECKS_DIR" >&2
  exit 2
fi

for _gate_file in "${GATE_FILES[@]}"; do
  # A gate file that cannot be read is a FAIL, never a silent skip: a gate that does not run is
  # how a capability becomes silently absent. (A gate's own non-zero VERDICT is not this — `gate`
  # returns 0 and records the failure itself, so only a load error reaches here.)
  if ! . "$_gate_file"; then
    printf '  "%s","FAIL","%s"\n' "$(basename "$_gate_file")" "the gate file did not load — the gate did not run"
    printf '%s\t%s\n' "$(basename "$_gate_file")" "the gate file did not load" >>"$VERDICT" 2>/dev/null || true
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  exit 0
fi
printf 'ci-verify: a gate failed — see the FAIL row above\nhelp: run the failing gate directly\n' >&2
exit 1
