#!/usr/bin/env bash
# nornir-job-work-intake.sh — the work road's intake tick (plan 365 phase 3).
# Issues labelled `ymir:work` in the repos named by `intake.repos` enter the queue: the claims ledger lets one
# seat pick each issue, and Mjölnir cuts the worktree and the worker. Nothing is picked when no repo is named.
# Row (the heart, every 10 minutes):   @heart @every:10 bin/time/nornir-job-work-intake.sh
HERE="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v gh >/dev/null 2>&1 || { echo "work-intake: gh is not installed — not armed"; exit 0; }
exec python3 "$HERE/../fleet/work.py" intake
