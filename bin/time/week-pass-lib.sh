#!/usr/bin/env bash
# week-pass-lib.sh — the one law the three weekly passes share.
#
# WHY THIS FILE EXISTS (2026-11-17). A weekly pass does four things and nothing else: it asks a
# door, turns the answer into ONE number and ONE line, appends ONE row to its own series, and
# speaks ONLY when the week is not clean. Three jobs doing that by hand is three chances to append
# twice, to rewrite a row, or to send a second line for one fault — so the law lives here, once,
# and each job is a door-call and a verdict.
#
#   . bin/time/week-pass-lib.sh
#   week_pass_init <name>                  resolve the home, the series, the notice door
#   week_pass_row <value> <detail>         append {at,value,detail} to <name>-week.jsonl
#   week_pass_rune <ok|fault> <message>    carve the Rune that says what this pass found
#   week_pass_notice <line>                ONE line, through the one door, keyed to the ISO week
#   week_pass_verdict <clean> <value> <detail> <line>
#                                          the four acts in their ruled order
#
# THE ROW IS APPENDED, NEVER REWRITTEN. The series is the history: no truncation, no compaction, no
# "latest only" file. A week that was dirty stays dirty in the record, and the count never falls.
#
# THE EXIT CODE IS THE JOB'S, and each job returns 0 when it MEASURED — clean or not. A non-zero row
# makes the scheduler raise its own HIGH line, so one fault would speak twice; the brief says one
# line. `2` is reserved for "the door could not answer at all", which is a real failure and deserves
# the scheduler's notice.
#
# ENV — the test seams, named so (the same habit `bin/ward/soak-sampler.sh` documents):
#   YMIR_WEEK_STATE    the series dir            (default <home>/hodd/state)
#   YMIR_WEEK_NOTIFY   the notice door           (default <root>/bin/notify/send.sh)
#   YMIR_WEEK_NOW      the instant a row carries (default the clock, UTC)
# Runes go to the home's ledger; `BROKK_RUNES_FILE` names another one (the engine's own override).
set -uo pipefail

week_pass_init() { # <name>
  WEEK_NAME="${1:?week_pass_init needs a pass name}"
  WEEK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  # The home is resolved by the one resolver, never restated (Rule 07).
  WEEK_HOME="${YMIR_HOME:-}"
  if [ -z "$WEEK_HOME" ] && [ -r "$WEEK_ROOT/bin/vault/hoard-lib.sh" ]; then
    . "$WEEK_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
    if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root WEEK_HOME 2>/dev/null || WEEK_HOME=""; fi
  fi
  [ -n "$WEEK_HOME" ] || WEEK_HOME="$WEEK_ROOT"

  WEEK_STATE="${YMIR_WEEK_STATE:-$WEEK_HOME/hodd/state}"
  WEEK_NOTIFY="${YMIR_WEEK_NOTIFY:-$WEEK_ROOT/bin/notify/send.sh}"
  WEEK_NOW="${YMIR_WEEK_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  WEEK_SERIES="$WEEK_STATE/$WEEK_NAME-week.jsonl"
  if [ -r "$WEEK_ROOT/bin/records/runes-append.sh" ]; then
    # shellcheck source=bin/records/runes-append.sh
    . "$WEEK_ROOT/bin/records/runes-append.sh"
  fi
  return 0
}

week_pass_stamp_key() { # the ISO week the row belongs to — one line per week, never per run
  python3 - "$WEEK_NOW" <<'PY' 2>/dev/null || date -u +%G-W%V
import sys
from datetime import datetime, timezone
raw = (sys.argv[1] or "").strip().replace("Z", "+00:00")
try:
    at = datetime.fromisoformat(raw)
except ValueError:
    print(datetime.now(timezone.utc).strftime("%G-W%V")); raise SystemExit
if at.tzinfo is None:
    at = at.replace(tzinfo=timezone.utc)
iso = at.isocalendar()
print(f"{iso[0]:04d}-W{iso[1]:02d}")
PY
}

week_pass_row() { # <value> <detail>  — appended, never rewritten
  local value="${1-}" detail="${2-}" dir
  dir="$(dirname "$WEEK_SERIES")"
  mkdir -p "$dir" || { printf 'week-%s: cannot make the series dir %s\n' "$WEEK_NAME" "$dir" >&2; return 1; }
  python3 - "$WEEK_SERIES" "$WEEK_NOW" "$value" "$detail" <<'PY'
import json, sys
path, at, value, detail = sys.argv[1:5]
if value in ("", "null", "None"):
    v = None
else:
    try:
        v = int(value)
    except ValueError:
        v = value
row = {"at": at, "value": v, "detail": detail}
with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
PY
}

week_pass_rune() { # <ok|fault> <message>
  local kind="${1:?ok or fault}" msg="${2-}"
  if declare -f runes_append >/dev/null 2>&1; then
    runes_append "nornir" "week.$WEEK_NAME.$kind" --message "$msg" >/dev/null 2>&1 \
      || printf 'week-%s: the rune could not be carved (non-fatal)\n' "$WEEK_NAME" >&2
  fi
  return 0
}

week_pass_notice() { # <one line>
  local line="${1-}"
  [ -n "$line" ] || return 0
  if [ ! -x "$WEEK_NOTIFY" ] && [ ! -r "$WEEK_NOTIFY" ]; then
    printf 'week-%s: no notice door at %s — the line stays on stdout\n' "$WEEK_NAME" "$WEEK_NOTIFY" >&2
    return 1
  fi
  # One key per pass per ISO week: a second run in the same week is one message, not two.
  "$WEEK_NOTIFY" --source cron --severity MEDIUM \
    --key "week-$WEEK_NAME-$(week_pass_stamp_key)" --message "$line" >/dev/null 2>&1 \
    || { printf 'week-%s: the notice door refused the line: %s\n' "$WEEK_NAME" "$line" >&2; return 1; }
  return 0
}

week_pass_verdict() { # <clean 0|1> <value> <detail> <one line>
  local clean="${1:?clean}" value="${2-}" detail="${3-}" line="${4-}"
  week_pass_row "$value" "$detail" || return 2
  if [ "$clean" = 0 ]; then
    week_pass_rune ok "$WEEK_NAME: clean — $detail"
    printf 'week-%s: clean — %s\n' "$WEEK_NAME" "$detail"
    return 0
  fi
  week_pass_rune fault "$WEEK_NAME: NOT CLEAN — $detail"
  week_pass_notice "$line"
  printf 'week-%s: NOT CLEAN — %s\n' "$WEEK_NAME" "$detail"
  return 0
}

week_pass_unmeasured() { # <why> — the door could not answer: a row that says so, never a zero
  week_pass_row "" "$1"
  week_pass_rune fault "$WEEK_NAME: could not measure — $1"
  printf 'week-%s: could not measure — %s\n' "$WEEK_NAME" "$1"
  return 2
}
