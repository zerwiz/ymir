#!/usr/bin/env bash
# 0025-brief-watch-row — seat the morning brief's watchdog in an existing home's schedule.
#
# WHY (2026-11-17). The 07:00 brief publishes its file and THEN exits 1 when a draft has
# aged, so the scheduler says "job failed (rc=1)" over a document that is complete. Worse,
# two of the four mornings say nothing at all: a drafts door that never shipped exits 0, and
# a row that never fired writes no record — so both read exactly like a clean morning.
# `bin/time/nornir-job-brief-watch.sh` now judges the morning and speaks one line. The row
# that runs it has to reach every home that already has a schedule, not only a fresh
# install — an update must not need a person to remember a line.
#
# What it does, in the operator's own `config/cron.yaml`:
#   · already present → says so and changes nothing (idempotent);
#   · otherwise inserts `@heart 07:05 bin/time/nornir-job-brief-watch.sh` immediately after
#     the 07:00 brief row, so the two read as a pair in his file;
#   · with no 07:00 row to sit beside, appends it at the end, under a dated comment.
#
# What it never does:
#   · it never rewrites, removes or reorders an existing line — a schedule is his, and a
#     migration that edits his times is a migration that lies about his day;
#   · it never writes a schedule where none exists (no `config/cron.yaml` means the home
#     runs the shipped example, which already carries the row): that home is DEFERRED, not
#     recorded, so the row is seated if he ever writes one;
#   · it never touches the repo's own `config/cron.yaml.example`, which ships the row already.
#
# Idempotent: applied once, and a second run changes nothing (it is also recorded in
# state/migrations). Exit 0 done · 3 deferred (no home, or no schedule yet).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  ymir_home_root HOME_DIR 2>/dev/null || HOME_DIR=""
fi
HOME_DIR="${HOME_DIR:-${YMIR_HOME:-}}"
[ -n "$HOME_DIR" ] || { printf '0025-brief-watch-row: no home recorded — deferred\n'; exit 3; }

CRON="$HOME_DIR/config/cron.yaml"
ROW='@heart 07:05 bin/time/nornir-job-brief-watch.sh'
ANCHOR='bin/time/nornir-job-daily-briefing.sh'

[ -d "$HOME_DIR/config" ] || mkdir -p "$HOME_DIR/config" 2>/dev/null || true
if [ ! -e "$CRON" ]; then
  printf '0025-brief-watch-row: no schedule in this home (%s) — deferred; the shipped example carries the row\n' \
    "config/cron.yaml"
  exit 3
fi

if grep -q 'nornir-job-brief-watch\.sh' "$CRON" 2>/dev/null; then
  printf '0025-brief-watch-row: already present in %s — nothing to do\n' "$CRON"
  exit 0
fi

TMP="$CRON.0025.$$"
trap 'rm -f "$TMP"' EXIT

BRIEF_WATCH_ROW="$ROW" PLACE_AFTER="$ANCHOR" python3 - "$CRON" "$TMP" <<'PY'
import os, sys

src, dst = sys.argv[1], sys.argv[2]
row = os.environ["BRIEF_WATCH_ROW"]
anchor = os.environ["PLACE_AFTER"]
COMMENT = [
    "# THE BRIEF'S OWN WATCHDOG (2026-11-17, migration 0025): five minutes after the brief, one row",
    "# says why the morning failed or is not clean — and what to do — or stays silent on a clean day.",
]

with open(src, "r", encoding="utf-8", errors="replace") as fh:
    lines = fh.read().splitlines()

out, placed = [], False
for line in lines:
    out.append(line)
    if not placed and anchor in line and not line.lstrip().startswith("#"):
        out.extend(COMMENT)
        out.append(row)
        placed = True

if not placed:
    if out and out[-1].strip():
        out.append("")
    out.append("# Seated by migration 0025 on 2026-11-17: no 07:00 brief row was found to sit beside.")
    out.append(row)

with open(dst, "w", encoding="utf-8") as fh:
    fh.write("\n".join(out) + "\n")
PY

if ! diff -q "$CRON" "$TMP" >/dev/null 2>&1; then
  mv "$TMP" "$CRON"
  trap - EXIT
  printf '0025-brief-watch-row: seated `%s` in %s\n' "$ROW" "$CRON"
else
  printf '0025-brief-watch-row: nothing to write — %s is already as it should be\n' "$CRON"
fi
exit 0
