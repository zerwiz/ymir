#!/usr/bin/env bash
# 0025-weekly-passes — seat the three weekly rows in an existing operator schedule.
#
# WHY. `config/cron.yaml.example` is what a FRESH machine installs; an existing home keeps its own
# `$YMIR_HOME/config/cron.yaml` and is never overwritten by an update. So a feature that ships only as a
# row in the example runs on new machines and on no other — the declared-but-dead fault this house has
# already paid for twice. The three weekly passes (the mail balance, the pin's distance, the tunnels'
# uptime) are seated here, idempotently, on every home that already has a schedule.
#
# WHAT IT DOES, and what it does not:
#   · appends a row ONLY when the command it runs is not already in the file — a row a person moved to
#     another minute is left exactly where he put it;
#   · appends at the END, under one comment; the operator's own rows are never reordered or rewritten;
#   · never removes, never edits in place, never touches another machine's home;
#   · a home with no `config/cron.yaml` is DEFERRED (exit 3): there is no schedule to add to, and the
#     install seats the example for that machine.
#
# Idempotent: a second run finds every commands_path present and changes nothing.
#
# 2026-11-17.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  ymir_home_root HOME_DIR 2>/dev/null || HOME_DIR=""
fi
[ -n "$HOME_DIR" ] || { printf '0025-weekly-passes: no home recorded — nothing to migrate\n'; exit 3; }

CRON="$HOME_DIR/config/cron.yaml"
DRY=0
[ "${1-}" = "--dry-run" ] && DRY=1

if [ ! -f "$CRON" ]; then
  printf '0025-weekly-passes: no schedule at %s — the install seats config/cron.yaml.example there\n' "$CRON"
  exit 3
fi

# The rows, in the order they run. 08:40 · 08:50 · 09:00 Monday; 09:15 belongs to the draft sweep.
rows=(
  "@heart Mon 08:40 bin/time/nornir-job-week-tunnels.sh"
  "@heart Mon 08:50 bin/time/nornir-job-week-mail.sh"
  "@heart Mon 09:00 bin/time/nornir-job-week-pin.sh"
)
doors=(
  "bin/time/nornir-job-week-tunnels.sh"
  "bin/time/nornir-job-week-mail.sh"
  "bin/time/nornir-job-week-pin.sh"
)

added=0
for i in "${!rows[@]}"; do
  door="${doors[$i]}"
  # Already scheduled — anywhere, on any minute. A row a person moved is still HIS row.
  if grep -qF -- "$door" "$CRON" 2>/dev/null; then continue; fi
  if [ "$added" = 0 ] && ! grep -qF -- "# — THREE WEEKLY PASSES" "$CRON" 2>/dev/null; then
    if [ "$DRY" = 1 ]; then
      printf '0025-weekly-passes: would add the weekly-pass comment block and %s\n' "$door"
    else
      {
        printf '\n# — THREE WEEKLY PASSES (2026-11-17) — one number a week in a series, a word only when the\n'
        printf '# week is not clean. Added by .agents/migrations/0025-weekly-passes.sh.\n'
      } >>"$CRON"
    fi
  fi
  if [ "$DRY" = 1 ]; then
    printf '0025-weekly-passes: would append: %s\n' "${rows[$i]}"
  else
    printf '%s\n' "${rows[$i]}" >>"$CRON"
    printf '0025-weekly-passes: appended: %s\n' "${rows[$i]}"
  fi
  added=$((added + 1))
done

[ "$added" = 0 ] && printf '0025-weekly-passes: all three rows already scheduled — nothing to do\n'
exit 0
