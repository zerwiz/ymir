#!/usr/bin/env bash
# nornir-job-skillopt-sleep.sh — SkillOpt overnight self-evolution.
#
# Runs SkillOpt-Sleep against Ymir's registered skills and Smíðja
# prompt files. Harvests today's session trajectories, mines recurring
# patterns, replays them, and consolidates validated skill edits behind
# a held-out validation gate.
#
# OUTPUT: stages best_skill.md artifacts under .agents/skills/*/staging/
#         — never auto-applies. Allfather reviews before merge.
#
# Environment:
#   BROKK_HOME, BROKK_STATE_OVERRIDE
#   SKILLOPT_PATH  path to the skillopt venv bin (default .venv/bin)
#   SKILLOPT_SLEEP_OPTS  extra args to skillopt-sleep run
#
# Safety: writes only to staging dirs and Runes. Never touches
# .agents/skills/*/SKILL.md directly. The Allfather approves adopted
# skills before they go live.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
SKILLOPT_PATH="${SKILLOPT_PATH:-$BROKK_HOME/.venv/bin}"
SLEEP_OPTS="${SKILLOPT_SLEEP_OPTS:-}"

# shellcheck source=bin/runes-append.sh
. "$SCRIPT_DIR/runes-append.sh"

STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STAGING="$BROKK_HOME/.agents/skills/skillopt-staging"

mkdir -p "$STATE" "$STAGING" 2>/dev/null || true

printf 'SKILLOPT-SLEEP - %s\n' "$STAMP"

# ---- 1. Pre-flight ----------------------------------------------------
if [ ! -x "$SKILLOPT_PATH/skillopt-sleep" ]; then
  msg="skillopt-sleep not found at $SKILLOPT_PATH/skillopt-sleep — run bin/skillopt-setup.sh first"
  printf 'skillopt: %s\n' "$msg"
  runes_append "skillopt" "sleep.skipped" --message "$msg" >/dev/null 2>&1 || true
  exit 0
fi

# ---- 2. Run SkillOpt-Sleep -------------------------------------------
# Harvests sessions from ~/.claude and ~/.codex (if present),
# mines recurring tasks, replays them, and stages best_skill.md.
# --dry-run: report only. --auto-adopt: never set (human-in-the-loop).
if [ -d "$BROKK_HOME/.claude" ] || [ -d "$BROKK_HOME/.codex" ]; then
  "$SKILLOPT_PATH/skillopt-sleep" run \
    --project "$BROKK_HOME" \
    --scope all \
    --source auto \
    --lookback-hours 24 \
    --max-sessions 50 \
    --max-tasks 20 \
    --target-skill-path "$STAGING/best_skill.md" \
    --progress \
    $SLEEP_OPTS 2>&1 | tee "$STATE/skillopt-sleep-$STAMP.log" || true
else
  msg="no Claude/Codex session dirs found at $BROKK_HOME — SkillOpt-Sleep needs agent transcripts"
  printf 'skillopt: %s\n' "$msg"
  runes_append "skillopt" "sleep.skipped" --message "$msg" >/dev/null 2>&1 || true
fi

# ---- 3. Stage report --------------------------------------------------
if [ -f "$STAGING/best_skill.md" ]; then
  size=$(wc -c <"$STAGING/best_skill.md" | tr -d '[:space:]')
  msg="staged best_skill.md (${size} bytes) — review before adopt"
else
  msg="no new proposals this cycle"
fi
printf 'skillopt: %s\n' "$msg"
runes_append "skillopt" "sleep.completed" --message "$msg" >/dev/null 2>&1 || true
