#!/usr/bin/env bash
# 0025-the-weekly-draft-sweep — an existing home gets the Monday 09:15 draft sweep row.
#
# WHY (plan 305, appended 2026-11-17 at the Allfather's word). The weekly sweep ships in the tree
# as `bin/mail/draft-age.sh --weekly`, and `config/cron.yaml.example` carries the row — but a
# CHECKOUT follows a `git pull` and a HOME does not. Without this migration the door would exist on
# every machine and be scheduled on none, which looks exactly like a house with no draft problems.
#
# What it does, on every home it reaches (a fresh install runs it too, through
# `bin/engine/ymir-migrate.sh apply` in the installer and in Gróa's update):
#
#   1. reads `$YMIR_HOME/config/cron.yaml` and does nothing when it already names the sweep —
#      the migration is idempotent by that fact, never by a marker it writes;
#   2. otherwise APPENDS the row, under a comment saying what it is and why it is on the heart;
#   3. touches nothing else: no other row is edited, reordered or removed, and a home with no
#      cron.yaml at all is left alone (there is no schedule there to add a row to).
#
# What it deliberately does NOT do:
#   · it never rewrites a row the operator wrote — the row is appended, and an operator who has
#     moved or disabled the sweep keeps his own choice (`--weekly` anywhere in the file is enough
#     to make this migration a no-op);
#   · it never runs the sweep. Scheduling a door is not running it.
#
# Usage: 0025-the-weekly-draft-sweep.sh          (run by bin/engine/ymir-migrate.sh apply)
# Env (test seams): YMIR_HOME · YMIR_MIGRATE_DRY=1
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  ymir_home_root HOME_DIR 2>/dev/null || HOME_DIR=""
fi
HOME_DIR="${HOME_DIR:-${YMIR_HOME:-}}"
[ -n "$HOME_DIR" ] || { printf '0025-the-weekly-draft-sweep: no home recorded — nothing to do\n'; exit 3; }

CRON="$HOME_DIR/config/cron.yaml"
ROW='@heart Mon 09:15 bin/mail/draft-age.sh --weekly'

if [ ! -r "$CRON" ]; then
  printf '0025-the-weekly-draft-sweep: no %s — this home has no schedule to add a row to\n' "$CRON"
  exit 0
fi

if grep -q -- '--weekly' "$CRON" 2>/dev/null; then
  printf '0025-the-weekly-draft-sweep: the weekly sweep is already scheduled in %s\n' "$CRON"
  exit 0
fi

if [ "${YMIR_MIGRATE_DRY:-0}" = 1 ]; then
  printf '0025-the-weekly-draft-sweep: would append "%s" to %s\n' "$ROW" "$CRON"
  exit 0
fi

{
  printf '\n'
  printf '# — THE WEEKLY DRAFT SWEEP (plan 305, seated by migration 0025) —\n'
  printf '# The 07:00 brief asks "is anything too old", inside a job that can itself be dead. The week\n'
  printf '# asks "what did I start and not finish": every draft oldest first, one trend row in\n'
  printf '# hodd/state/draft-trend.jsonl, and ONE phone line with a send/edit/discard button per draft.\n'
  printf '# A week with no drafts says nothing and carves one no-op Rune. On the heart because the\n'
  printf '# mailbox is ingested there; 09:15 so it never pre-empts the morning brief.\n'
  printf '%s\n' "$ROW"
} >>"$CRON" || { printf '0025-the-weekly-draft-sweep: could not write %s\n' "$CRON" >&2; exit 1; }

printf '0025-the-weekly-draft-sweep: appended the weekly sweep to %s\n' "$CRON"
