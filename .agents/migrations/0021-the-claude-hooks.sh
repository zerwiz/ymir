#!/usr/bin/env bash
# 0021-the-claude-hooks — seat the fleet's Claude hooks in a home installed before 2026-11-10.
#
# WHY (2026-11-10, the Allfather's law): every Claude seat in the fleet carries THREE user-scope
# hooks, because a Claude agent in this house must not build a second worker tree of its own:
#
#   SessionStart  load-agents-md.sh   Claude Code reads CLAUDE.md, never a project's AGENTS.md;
#                                     this injects the project contract so the law reaches Claude.
#   PreToolUse    eindri-only.sh      (Agent|Task) workers are Eindri, never Claude subagents —
#                                     the hook DENIES the spawn and names bin/agents/eindri-start.sh.
#   Stop          ymir-arm.sh         (asyncRewake) the Gná arm reaches a Claude seat in ANY
#                                     project, resolved from pi's root record, not $CLAUDE_PROJECT_DIR.
#
# A `git pull` reaches the repo's `.claude/hooks/` but NOT the user's `~/.claude/settings.json`, so
# an existing home needs this door. It calls the one owner of the wiring:
# `bin/seat/harness-extensions-install.sh`, which copies the hook scripts and adds each entry as a
# NAMED hook (idempotent: a second run finds every entry current). A host with no Claude is a clean
# skip (RULES/25) — the script says so and changes nothing.
#
# It never merges a user's JSON blindly: only the three named entries are appended, a backup is
# kept, and every other hook and permission the operator owns stays where it is.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
say() { printf '0021: %s\n' "$1"; }

door="$ROOT/bin/seat/harness-extensions-install.sh"
[ -x "$door" ] || { say "no bin/seat/harness-extensions-install.sh in this tree — nothing to seat"; exit 0; }

if ! command -v claude >/dev/null 2>&1; then
  say "no claude on this host — clean skip (the hooks are seated the day Claude is installed)"
  exit 0
fi

out="$("$door" 2>&1)"; rc=$?
printf '%s\n' "$out" | grep '"claude' | sed 's/^ *//; s/^"//; s/",/ — /; s/"$//' | sed 's/^/0021: /'
[ "$rc" = 0 ] || say "a harness could not be seated — bin/seat/harness-extensions-install.sh --check names it"
say "done — the AGENTS.md loader and the Eindri-only ward are seated; the global Gná arm is opt-in (config/claude-global-arm)"
exit 0
