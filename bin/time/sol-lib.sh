#!/usr/bin/env bash
# sol-lib.sh — Sól's stamp for shell roads. Sourced, never executed.
#
# Every line a person or the helm reads begins with the local date and time, in ONE shape — `2026-11-12 14:55 CET`
# (plan 271, appended 2026-11-12; plan 272, fault 4) — so a repeat cannot be mistaken for a new event. The shape is
# defined by `bin/time/sol.sh line`; this lib renders the same shape without a process per line (`date`, in the zone
# Sól resolves: $YMIR_TZ, else the machine's). Machine fields (epochs, `heartbeat=`) stay as they are for parsing;
# whatever SHOWS them renders them through `sol_from_epoch`.
#
#   sol_line                      → 2026-11-12 14:55 CET            (now)
#   sol_from_epoch <epoch>        → 2026-11-12 14:55 CET            (an instant already on a machine field)
#   sol_stamped <text…>           → 2026-11-12 14:55 CET — <text>   (idempotent: a line already stamped is unchanged)
#   some_command | sol_prefix     → every line of stdin, stamped
#
# Idempotent by construction: a line that already starts with a date is not stamped twice.
SOL_STAMP_FMT='%Y-%m-%d %H:%M %Z'

sol_line() {
  if [ -n "${YMIR_TZ:-}" ]; then TZ="$YMIR_TZ" date +"$SOL_STAMP_FMT"; else date +"$SOL_STAMP_FMT"; fi
}

sol_from_epoch() {  # <epoch>
  local e=${1:-}
  case "$e" in ''|*[!0-9]*) printf '%s' "${e:-unknown time}"; return 0 ;; esac
  if [ -n "${YMIR_TZ:-}" ]; then TZ="$YMIR_TZ" date -d "@$e" +"$SOL_STAMP_FMT"; else date -d "@$e" +"$SOL_STAMP_FMT"; fi
}

sol_is_stamped() {  # <text> — does it already begin with a Sól stamp (or any ISO date)?
  case "${1:-}" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]*) return 0 ;; esac
  return 1
}

sol_stamped() {  # <text…>
  local t="$*"
  if sol_is_stamped "$t"; then printf '%s' "$t"; else printf '%s — %s' "$(sol_line)" "$t"; fi
}

sol_prefix() {  # stdin → stdout, every non-empty line stamped once
  local l now; now="$(sol_line)"
  while IFS= read -r l || [ -n "$l" ]; do
    if [ -z "$l" ]; then printf '\n'; elif sol_is_stamped "$l"; then printf '%s\n' "$l"; else printf '%s — %s\n' "$now" "$l"; fi
  done
}
