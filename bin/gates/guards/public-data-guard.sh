#!/usr/bin/env bash
# public-data-guard.sh — the TREE scan for RULES/04: templates and logic, and nothing private.
#
# The public repository may carry templates (`*.example`, schemas, synthetic names) and logic (the
# code that reads the home at run time). It may not carry a secret, the operator's own words, a
# private address or a personal mailbox — "whether or not they are a secret", and "not as a value,
# not as an example filled with the real thing" (RULES/04, 2026-10-01).
#
# This is the WARD in the one list (`bin/gates/guards.sh`); the judgement itself lives in
# public-guard.py, so a person can run either and get the same answer:
#
#   bin/gates/guards/public-data-guard.sh          # every tracked file
#   python3 bin/gates/guards/public-guard.py --list # the four classes and what each allows
#
# Exit: 0 clean · 1 findings · 2 usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# SCOPED (plan 243 §3, part B · 2026-11-11). This is the ward whose whole-tree walk made the
# pre-push slow — 5,476 files, 22.5 s, and the answer for 5,475 of them could not have changed.
# guards.sh hands a scoped ward the changed paths as arguments, and the scan is per file, so a
# one-file push reads one file. With no paths it still walks the whole tree, which is what CI
# (`guards.sh --full`) and a person typing the ward by hand both do: nothing is scoped away.
args=("$@")
[ "${args[0]-}" = check ] && args=("${args[@]:1}")
# THE RANGE (2026-11-16). guards.sh hands a scoped ward the changed FILES and, in
# YMIR_GUARD_BASE, the revision the push starts from. A file the push touched is not the same
# thing as the lines the push ADDS: a note edited to record a new fix re-carries every sentence
# it already had, and refusing the push for an old sentence punishes the wrong hand — the
# "inherited" rule of plan 243 §3 part D, applied to a line rather than a path. With no base (CI's
# --full, or a person running the ward by hand) every line is judged, which is the binding gate.
base="${YMIR_GUARD_BASE:-}"
if [ -n "$base" ] && [ "${#args[@]}" -gt 0 ]; then
  exec python3 "$ROOT/bin/gates/guards/public-guard.py" --added "$base" "${args[@]}"
fi
if [ "${#args[@]}" -gt 0 ]; then
  exec python3 "$ROOT/bin/gates/guards/public-guard.py" "${args[@]}"
fi
exec python3 "$ROOT/bin/gates/guards/public-guard.py" --tree
