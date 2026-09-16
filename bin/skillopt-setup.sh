#!/usr/bin/env bash
# skillopt-setup.sh — one-time SkillOpt installation for Ymir.
#
# Usage: bin/skillopt-setup.sh [--dry-run]
#
# What it does:
#   1. Creates the venv (uv venv .venv) if it doesn't exist
#   2. Installs skillopt + skillopt-sleep into it
#   3. Registers Ymir's highest-ROI skills for training
#   4. Runs a quick smoke check (skillopt-sleep --help)
#
# Does NOT install model API keys — those come from the
# operator's config (config/agents.yaml, .env.local).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
VENV="$BROKK_HOME/.venv"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

echo "SKILLOPT SETUP — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "root=$BROKK_HOME venv=$VENV dry_run=$DRY_RUN"

# ---- 1. Venv --------------------------------------------------------
if [ -d "$VENV/bin" ] && [ -x "$VENV/bin/python" ]; then
  echo "venv: already exists at $VENV"
else
  if [ "$DRY_RUN" = "1" ]; then
    echo "venv: would create → uv venv $VENV"
  else
    echo "venv: creating → uv venv $VENV"
    uv venv "$VENV" || { echo "venv: FAILED"; exit 1; }
  fi
fi

# ---- 2. Install -----------------------------------------------------
if [ -x "$VENV/bin/skillopt-sleep" ]; then
  echo "skillopt: already installed ($(date -u +%Y-%m-%d))"
else
  if [ "$DRY_RUN" = "1" ]; then
    echo "skillopt: would install → uv pip install --python $VENV/bin/python skillopt skillopt-sleep"
  else
    echo "skillopt: installing → uv pip install --python $VENV/bin/python skillopt skillopt-sleep"
    uv pip install --python "$VENV/bin/python" skillopt skillopt-sleep 2>&1 | tail -5
    [ "${PIPESTATUS[0]:-0}" = "0" ] || { echo "skillopt: FAILED"; exit 1; }
  fi
fi

# ---- 3. Smoke check --------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  echo "check: would run → $VENV/bin/skillopt-sleep --help"
else
  echo "check: running smoke test"
  "$VENV/bin/skillopt-sleep" --help >/dev/null 2>&1 \
    && echo "skillopt: OK (sleep CLI responding)" \
    || echo "skillopt: smoke check failed — investigate"
fi

# ---- 4. Registered skills (what to train first) ----------------------
echo ""
echo "Registered skills for first training cycle:"
echo "  .agents/skills/smidja-instructions/SKILL.md   (smidja-instructions)"
echo "  .agents/skills/smidja-start/SKILL.md          (smidja-start)"
  echo "  .agents/skills/galdr-ymirsystem/SKILL.md     (galdr)"
echo ""
echo "Manual registration:"
echo "  .venv/bin/skillopt register \\"
echo "    .agents/skills/<name>/SKILL.md --name <name>"
echo ""
echo "First training:"
echo "  .venv/bin/skillopt-train --config configs/<skill>.yaml"
echo ""
echo "Nightly cron: 00:30 bin/nornir-job-skillopt-sleep.sh"
echo "Auto-adopt: NEVER — the Allfather reviews staged artifacts."
