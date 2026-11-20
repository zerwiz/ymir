#!/usr/bin/env bash
# nornir-job-worktree-housekeeping.sh — the daily reckoning of what the worktrees cost.
#
# REPORT ONLY, by law. A cron row that deletes is a cron row that can delete the one commit
# that existed nowhere else; so this job runs `bin/forge/housekeeping.sh report`, writes it
# into the home beside the ward's reports, and stops. Reclaiming stays a human's `--yes`.
#
# It records three numbers that matter: how many worktrees and branches stand, how much is
# provably reclaimable, and — the loud one — how much work exists ONLY on this machine.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

HK="$ROOT/bin/forge/housekeeping.sh"
[ -x "$HK" ] || { printf 'worktree-housekeeping[1]{state}:\n  "skip","no bin/forge/housekeeping.sh"\n'; exit 0; }

. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi

report="$("$HK" report 2>&1 || true)"
printf '%s\n' "$report"

if [ -n "$HOME_DIR" ]; then
  out="$HOME_DIR/hodd/memory/worktrees/$(date +%Y-%m-%d).md"
  mkdir -p "$(dirname "$out")"
  {
    printf '# Worktree reckoning — %s\n\n' "$(date -Iseconds)"
    printf '```\n%s\n```\n' "$report"
    printf '\nReclaim: `bin/forge/housekeeping.sh clean --yes` (a human decision; this job never removes).\n'
  } >>"$out"
  printf 'worktree-housekeeping[1]{report}:\n  "%s"\n' "${out#$HOME_DIR/}"
fi

# Non-zero when work exists only here, so a gate or a reader notices.
"$HK" check >/dev/null 2>&1 || exit 1
exit 0
