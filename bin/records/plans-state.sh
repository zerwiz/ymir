#!/usr/bin/env bash
# plans-state.sh — the plans, as data: every shelf the registry names, read once (plan 298 §2.1).
#
#   plans-state.sh                build hodd/registry/plans-state.yaml from the registry and the ledgers
#   plans-state.sh --stdout       print it instead of writing it
#   plans-state.sh --json         the same data, for a surface
#   plans-state.sh --check        exit 1 when a shelf the registry names is absent, or a number collides
#   plans-state.sh --with-prs     also ask GitHub whether a plan's PR merged (the only network call)
#   plans-state.sh --self-test    prove done-vs-open on a fixture home
#
# Why (plan 298, the Allfather's word, 2026-11-15): "I need a system thats in the registry that keeps my
# peronal todolist up to date with what plans are not done yet." His list's measured half was typed
# by hand and stamped `as_of 2026-11-11`, so it lied on every day after. The plans are already
# written down; this door joins them and nothing else.
#
# Where the shelves come from: `hodd/identity/projects.yaml`, each project's
# `records.in_home.plans` / `records.in_home.plan_index` and `records.in_repo.plans_ledger` /
# `records.in_repo.plans`. A shelf the registry names and that is not there is reported as absent
# with its path — never counted as an empty shelf, because an empty shelf and a missing one are
# different facts.
#
# A plan's state is `done` ONLY on evidence, carried with the reason: a `state:` header line
# (the new convention), a `Status:` line (the old one), a `register.md` row saying done, or — with
# --with-prs — a PR the plan names that GitHub says merged. Everything else is `open`: silence is
# not finished work, the same rule the merge gate uses.
#
# The output is GENERATED and git-ignored in the home (like bin/*/INDEX.md in the repo): a
# generated file that can conflict is a file that will.
#
# Exit: 0 ok · 1 --check found a finding · 2 the home or the registry could not be read.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR" && while [ ! -d "$PWD/RULES" ] || [ ! -d "$PWD/bin" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
# The home is resolved, never assumed (RULES/07): the one resolver is bin/vault/hoard-lib.sh.
if [ -z "${YMIR_HOME:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then H=""; ymir_home_root H; [ -n "$H" ] && export YMIR_HOME="$H"; fi
fi
export YMIR_REPO_ROOT="$ROOT"
exec python3 "$DIR/plans_state.py" "$@"
