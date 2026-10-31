#!/usr/bin/env bash
# nornir-job-doctor.sh — Eir, the healer, on the schedule.
#
# Every day the surfaces are checked so a desktop that cannot open is
# REPORTED, never silently dead (P8, 2026-09-24). Stateless: check, record a
# rune, exit — the same shape as the other Nornir jobs. A broken surface
# exits 1 so the cron log carries the failure; the rune is the audit record.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ]; then
  [ -r "$SCRIPT_DIR/../desktop/electron-lib.sh" ] && { . "$SCRIPT_DIR/../desktop/electron-lib.sh"; YMIR_ELECTRON_LIB_LOADED=1; }
fi

[ -x "$SCRIPT_DIR/../agents/eir-doctor.sh" ] || { printf 'nornir-job-doctor[1]{state}:\n  "skip","no eir-doctor.sh"\n'; exit 0; }

if out="$("$SCRIPT_DIR/../agents/eir-doctor.sh" check 2>&1)"; then
  printf 'nornir-job-doctor[1]{state}:\n  "ok","every surface healthy"\n'
  # shellcheck source=bin/records/runes-append.sh
  . "$ROOT/bin/records/runes-append.sh"
  runes_append "nornir" "doctor.ok" --message "Eir checked every surface: all healthy" >/dev/null \
    || printf 'nornir-job-doctor: rune append failed (non-fatal)\n'
  exit 0
fi

broken="$(printf '%s' "$out" | sed -n '2s/.*,\([0-9][0-9]*\)$/\1/p')"
printf 'nornir-job-doctor[1]{state,broken}:\n  "broken",%s\n' "${broken:-?}"
printf '%s\n' "$out" | grep -E '"(shells|graphics|sessrumnir)"' | sed 's/^/  /'
# shellcheck source=bin/records/runes-append.sh
. "$ROOT/bin/records/runes-append.sh"
runes_append "nornir" "doctor.broken" --message "Eir found ${broken:-?} broken surface(s) — a desktop cannot open and has been reported" >/dev/null \
  || printf 'nornir-job-doctor: rune append failed (non-fatal)\n'
exit 1