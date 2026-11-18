#!/usr/bin/env bash
# nornir-job-dispatch.sh — the dispatcher's clock: one run, one record, one verdict.
#
#   nornir-job-dispatch.sh            the scheduled act: read the queues, propose, record
#   nornir-job-dispatch.sh --check    health only, nothing written (a gate or a hand may call it)
#   nornir-job-dispatch.sh --dry-run  read and report, write nothing
#
# DISPATCH_HOURS / DISPATCH_MAX / DISPATCH_ATTEMPT_CAP / DISPATCH_WAKE_TAIL / GNA_DESK_URL are read by
# the door (bin/dispatch/dispatch.sh) and are documented there; this job adds no second setting.
#
# A Nornir job starts, does one thing, writes its record and exits. It owns no state: the run ledger
# (hodd/state/dispatch/runs.jsonl) is the door's, and this file only reports what the door said.
#
# THE ONE LAW THIS JOB CARRIES: ABSENCE IS A FAILURE, NOT AN EMPTY LIST. A door that cannot read its
# input says so in Runes and on stdout, and the job exits non-zero — it never renders an unreadable
# queue as "nothing to do".
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOOR="$ROOT/bin/dispatch/dispatch.sh"

# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true

MODE="${1:-run}"
RUNES="$ROOT/bin/records/runes-append.sh"

say() { printf 'dispatch[%s] %s\n' "$MODE" "$*"; }

# One resolver, no guessed home (Rule 07): if the home cannot be named, this job refuses — a door that
# invents a path writes to a store nobody reads.
if [ -z "${HOME_R:-}" ] || [ ! -d "$HOME_R" ]; then
  say "FAIL the home is unresolved (bin/vault/hoard-lib.sh) — refusing to guess a path"
  exit 3
fi
if [ ! -x "$DOOR" ]; then
  say "FAIL the door is missing at $DOOR — the register and the tree disagree"
  exit 4
fi

case "$MODE" in
  run|--check|--dry-run|--json) ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) say "unknown mode $MODE (run | --check | --dry-run)"; exit 2 ;;
esac

out="$(bash "$DOOR" "$MODE" 2>&1)"
rc=$?
printf '%s\n' "$out"

# The ledger holds every run; Runes gets the runs a person would act on — one that changed his list,
# or one that failed — so the audit trail is not a ten-minute heartbeat.
case "$rc" in
  0)
    if printf '%s\n' "$out" | grep -q '^verdict: work'; then
      [ -x "$RUNES" ] && "$RUNES" dispatch dispatch-run \
        --message "work: proposals written to his list — every row in hodd/state/dispatch/runs.jsonl" \
        >/dev/null 2>&1 || true
    fi
    ;;
  *)
    [ -x "$RUNES" ] && "$RUNES" dispatch dispatch-run \
      --message "rc=$rc · $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" >/dev/null 2>&1 || true
    say "FAIL the door refused to answer cleanly (rc=$rc) — reported, never rendered as 'nothing to do'"
    ;;
esac

exit $rc
