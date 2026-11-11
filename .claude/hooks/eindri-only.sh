#!/usr/bin/env bash
# eindri-only.sh — Claude Code PreToolUse(Agent|Task): the Allfather's law, 2026-11-10.
#
# Workers are Eindri, never Claude subagents. A Claude seat that spawns its own
# subagents builds a second, invisible worker tree beside the house: no Yggdrasil
# worktree, no Utgard sandbox, no Rune, no seat the Allfather can find.
#
# This hook DENIES the Agent and Task tools and names the Ymir road instead, so the
# model reads the refusal as an instruction rather than a mysterious block. It is
# wired by bin/seat/harness-extensions-install.sh as ONE named PreToolUse entry in
# ~/.claude/settings.json, for every Claude seat in the fleet.
#
# It always prints a decision; a hook that prints nothing lets the tool through.
# jq is preferred; python3 is the fallback. If neither exists it exits 0 (the tool
# runs) because a broken notification must not silently become a dead seat — the
# wiring check names the missing dependency instead.

deny_reason='LAW (Allfather, 2026-11-10): never use Claude subagents. Every worker is an Ymir Eindri: bash "$HOME/ymir/bin/agents/eindri-start.sh" "<request>" --id <task-id> [--project <dir>] (or bin/agents/agent-run.sh <figure> "<task>"). Seated in herdr, on a Yggdrasil worktree, armed. If no Eindri road works, do it inline or ask the Allfather.'

if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$deny_reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$deny_reason" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
      "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}))
PY
fi
exit 0
