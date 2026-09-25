#!/usr/bin/env bash
# ci-verify.sh — what CI must prove, in one command, for BOTH hosts.
#
# GitHub Actions and Forgejo Actions are two doors to the same room, so neither holds a
# copy of the checks: both call THIS. A workflow that re-listed the steps would be a second
# place for them to drift, which is the failure this whole repository is being taught to stop.
#
# Usage:
#   ci-verify.sh            # run every gate CI owes
#   ci-verify.sh --fast     # skip the heavy one (the real npm install)
#
# Exit: 0 everything proved · 1 a gate failed · 2 usage.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

FAST=0
case "${1-}" in
  -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --fast)    FAST=1 ;;
  "")        ;;
  *)         printf 'error: unknown flag %s\nhelp: ci-verify.sh [--fast]\n' "${1-}" >&2; exit 2 ;;
esac

fail=0
printf 'ci_verify[4]{gate,status,detail}:\n'

gate() {  # <name> <description> <command...>
  local name="$1" what="$2"; shift 2
  local out; out="$( "$@" 2>&1 )" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  "%s","PASS","%s"\n' "$name" "$what"
  else
    printf '  "%s","FAIL","%s — %s"\n' "$name" "$what" "$(printf '%s' "$out" | tail -1 | cut -c1-88)"
    fail=1
  fi
}

gate ward        "the tree wards (runtime, defaults)"   bash "$ROOT/bin/guards.sh"
gate compliance  "the 15 governance gates"              bash "$ROOT/.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh"
if [ "$FAST" = 1 ]; then
  printf '  "%s","SKIP","%s"\n' pr-pretest "skipped by --fast"
else
  gate pr-pretest  "a REAL npm install of the publish artifact" bash "$ROOT/bin/pr-pretest.sh"
fi

if [ "$fail" -eq 0 ]; then
  exit 0
fi
printf 'ci-verify: a gate failed — see the FAIL row above\nhelp: run the failing gate directly\n' >&2
exit 1
