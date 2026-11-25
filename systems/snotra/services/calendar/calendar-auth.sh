#!/usr/bin/env bash
# calendar-auth.sh — re-grant the calendar through the ONE sign-in, the connect door.
#
# Why it changed (plan 375 B2, 2026-11-25): this door used to run its own sign-in and write a second
# refresh token, MANAGANDR_OAUTH_REFRESH_TOKEN, into the vault by decrypting and re-encrypting it by
# hand. That was a second grant for one person (its calendar.events scope sits inside the connect
# door's grant) and a second writer of the vault (it once wrote an empty vault, 2026-11-07). Now it
# runs `bin/mail/connect.sh google`: one consent, one grant (SNOTRA_GOOGLE_REFRESH_TOKEN), written by
# bin/vault/hodd-set.sh. The calendar reader and the voice tools read that grant first.
# The old grant is not deleted: a home that still has it keeps working until the operator revokes it.
#
# Usage:
#   calendar-auth.sh --url              print the authorization URL and exit (nothing listens)
#   calendar-auth.sh --store            sign in once; the grant is stored by the connect door
#
# Env: YMIR_OAUTH_LOOPBACK_PORT (default 8767; CALENDAR_AUTH_PORT still read), CHROMIUM_PROFILE (opens
#      that Chromium profile when chromium is installed). CALENDAR_WRITE is still accepted: the one
#      grant always carries calendar.events (read and write), so both values ask for the same consent.
#
# Exit: 0 ok · 1 error · 2 usage · 3 refused (the client is not in the vault: run bin/mail/connect.sh setup)
set -euo pipefail
VERSION="2.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
MODE="${1:---url}"; shift || true
case "$MODE" in --url|--store) ;; *) sed -n '2,23p' "$0" >&2; exit 2 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
DOOR="$ROOT/bin/mail/connect.sh"
[ -x "$DOOR" ] || [ -r "$DOOR" ] || { printf 'error: the connect door is missing at %s\n' "$DOOR" >&2; exit 1; }
# One sign-in port for every Google door (plan 276): YMIR_OAUTH_LOOPBACK_PORT, then the old CALENDAR_AUTH_PORT.
if [ -z "${YMIR_OAUTH_LOOPBACK_PORT:-}" ] && [ -n "${CALENDAR_AUTH_PORT:-}" ]; then
  export YMIR_OAUTH_LOOPBACK_PORT="$CALENDAR_AUTH_PORT"
fi

if [ "$MODE" = --url ]; then exec bash "$DOOR" google --print-url; fi

# --store: the connect door signs in. With chromium present, the chosen profile opens the consent page
# (what this door always did); otherwise the door opens the default browser itself.
if ! command -v chromium >/dev/null 2>&1; then exec bash "$DOOR" google; fi
URLF="$(mktemp)"; trap 'rm -f "$URLF"' EXIT
bash "$DOOR" google --no-browser --consent-url-out "$URLF" &
pid=$!
for _ in $(seq 1 100); do [ -s "$URLF" ] && break; kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
if [ -s "$URLF" ]; then
  printf 'Opening Chromium (%s) for the one Google sign-in...\n' "${CHROMIUM_PROFILE:-Profile 1}"
  chromium --profile-directory="${CHROMIUM_PROFILE:-Profile 1}" "$(head -1 "$URLF")" >/dev/null 2>&1 &
fi
wait "$pid"
