#!/usr/bin/env bash
# nornir-job-snotra-autojoin.sh — the clock that keeps Snotra in the Allfather's meetings.
#
# THE FAULT IT ENDS. `snotra-autojoin.sh scan` could name the meeting and `run --apply` could
# dispatch the bot, but nothing ran either on a cadence: a meeting was joined only if a hand
# remembered to type the door. A clock that is not scheduled is a capability nobody has.
#
# WHAT IT DOES
#   1. asks the engine whether it is up (`snotra-bot.sh health`). No engine, no bot: this is a
#      CLEAN SKIP with its reason printed (Rule 25), never a red row and never a false green;
#   2. scans the calendar cache and dispatches the bots the plan allows (`run --apply`), which
#      records a meeting as joined ONLY when the door succeeded;
#   3. carves one Rune for the run and prints one line.
#
# Role: ungated on purpose — auto-join belongs to the seat whose calendar is being read, and
# every seat that runs it reads its own hoard. A meeting already joined is skipped by the plan's
# own `joined` list, so a five-minute cadence cannot dispatch the same bot twice.
#
# Exit: 0 ran or cleanly skipped · 1 the doors are present and one of them failed
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'nornir-snotra-autojoin: the hoard is unresolved\n' >&2; exit 1; }
BOT="$ROOT/systems/snotra/services/ear/snotra-bot.sh"
AUTOJOIN="$ROOT/systems/snotra/services/ear/snotra-autojoin.sh"

export YMIR_HOME="$HOME_R"

if ! health="$("$BOT" health 2>&1)"; then
  printf 'snotra-autojoin: skip — no bot engine: %s\n' "$(printf '%s' "$health" | tail -1)"
  exit 0
fi

if ! out="$("$AUTOJOIN" run --apply 2>&1)"; then
  printf 'snotra-autojoin: FAILED — %s\n' "$(printf '%s' "$out" | tail -1)" >&2
  [ -x "$ROOT/bin/records/runes-append.sh" ] && \
    "$ROOT/bin/records/runes-append.sh" brokk nornir-snotra-autojoin --message \
      "Snotra auto-join failed: $(printf '%s' "$out" | tail -1)" >/dev/null 2>&1 || true
  exit 1
fi

dispatched="$(printf '%s\n' "$out" | grep -c '^JOIN' || true)"
joined_note="$(printf '%s\n' "$out" | grep -c '^fail' || true)"
printf 'snotra-autojoin: %s dispatched · %s refused · engine %s\n' \
  "${dispatched:-0}" "${joined_note:-0}" "$(printf '%s' "$health" | tr '\t' ' ')"
if [ -x "$ROOT/bin/records/runes-append.sh" ] && [ "${dispatched:-0}" -gt 0 ]; then
  "$ROOT/bin/records/runes-append.sh" brokk nornir-snotra-autojoin --message \
    "Snotra auto-join: ${dispatched} dispatched, ${joined_note} refused" >/dev/null 2>&1 || true
fi
exit 0
