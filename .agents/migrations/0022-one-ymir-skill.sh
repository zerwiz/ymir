#!/usr/bin/env bash
# 0022-one-ymir-skill — ONE Ymir skill in every root, ONE unscanned store behind it (plan 248 P3b).
#
# WHY (2026-11-11, RULES/51 "ONE YMIR SKILL IN EVERY ROOT" and "THE STORE IS NEVER SCANNED"):
# every skill a harness lists puts its description into EVERY turn. Outside the repo a root agent
# had none of Ymir's craft; inside it Claude listed all the shipped skills through the repo link
# `.claude/skills -> ../.agents/skills`. The answer is one root skill, `ymir`, whose body is the
# generated index of every skill by path into a store no harness scans.
#
# A home installed before this day needs three things a `git pull` cannot give it:
#   1. box skills moved OUT of ~/.agents/skills (pi walks it recursively) into the box shelf
#      $XDG_DATA_HOME/ymir/box-skills (XDG's data home) — CARRIED INTACT (RULES/06): the copy is compared file for
#      file before the source is gone, and nothing already in the box is overwritten;
#   2. the store, the root skill and Claude's link seated (bin/agents/skill-index.sh --root);
#   3. the retired repo link `.claude/skills` removed from the checkout this runs in, where it
#      has exactly the old shape (a real directory or another target is left untouched).
#
# Idempotent: a second run moves nothing, links nothing new and finds the root current.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
say() { printf '0022: %s\n' "$1"; }

gen="$ROOT/bin/agents/skill-index.sh"
[ -x "$gen" ] || { say "no bin/agents/skill-index.sh in this tree — nothing to seat"; exit 0; }

# 1 + 2: the box move, then the store and the one root skill
bash "$gen" --adopt-box 2>&1 | sed 's/^/0022: /'
out="$(bash "$gen" --root 2>&1)"; rc=$?
printf '%s\n' "$out" | sed 's/^/0022: /'
[ "$rc" = 0 ] || say "the root skill is not yet current — bin/agents/skill-index.sh --root-check names why"

# 3: the repo link that doubled the root in a session opened inside the checkout
if [ -L "$ROOT/.claude/skills" ] && [ "$(readlink "$ROOT/.claude/skills")" = "../.agents/skills" ]; then
  rm -f "$ROOT/.claude/skills" && say "retired the repo link .claude/skills (the root ymir skill serves Claude)"
fi

say "done — one ymir skill in every root; every other skill is a line in its index"
exit 0
