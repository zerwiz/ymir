#!/usr/bin/env bash
# calendar-ask.sh — the shell door onto Mánagandr, the read calendar.
#
# One reader (tools/calendar/reader.mjs), this thin door. It answers the one
# question a cron job asks — "is the Allfather free?" — as an EXIT CODE, so a job
# branches with no parsing and no jq:
#
#   0   free      — the window is provably free
#   10  busy      — the window is provably booked
#   20  unknown   — the reader cannot prove either (no grant, no cache, vendor down)
#   2   usage     — this door was called wrong
#
# UNKNOWN IS NOT FREE. An empty result and an unreadable result are never the
# same code: a dead calendar must never silently stop the house (the Nornir
# deferral guard fails open on THIS code, deliberately).
#
# Subcommands:
#   probe [--titles]   structural status: id, as_of, count, reason (no event data)
#   busy  [window]     0 free / 10 busy / 20 unknown
#   free  [window]     the same predicate under its negative name
#   json  [window]     the full normalised set (the data door)
#
# Flags: --window <6w|7d|Nh|ISO..ISO>  --now <ISO>  --fixture <file>  --cache <file>
#        --refresh  --titles  --probe  --json  -h|--help
#
# READ-ONLY: no create/update/delete verb exists here or in the reader. The only
# write is the local cache in the hoard state. No title, attendee or location is
# ever logged by this door; `probe` prints none unless `--titles` is asked for.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READER="$ROOT/tools/calendar/reader.mjs"

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/hoard-lib.sh" ]; then . "$_yh/bin/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
ymir_home_root YMIR_HOME 2>/dev/null || true
export MANAGANDR_VAULT="${MANAGANDR_VAULT:-${YMIR_HOME:-}}"

EXIT_FREE=0
EXIT_BUSY=10
EXIT_UNKNOWN=20
EXIT_USAGE=2

usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; }

SUB=""
WINDOW=""
NOW=""
FIXTURE=""
CACHE=""
REFRESH=0
TITLES=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    busy|free|probe|json)
      [ -n "$SUB" ] || SUB="$1"; shift ;;
    --probe|-p)     SUB="probe"; shift ;;
    --json)         SUB="json"; shift ;;
    --window|-w)    WINDOW="${2-}"; shift 2 ;;
    --now)          NOW="${2-}"; shift 2 ;;
    --fixture)      FIXTURE="${2-}"; shift 2 ;;
    --cache)        CACHE="${2-}"; shift 2 ;;
    --refresh|-r)   REFRESH=1; shift ;;
    --titles)       TITLES=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    -*)             printf 'error: unknown flag %s\nhelp: calendar-ask.sh [probe|busy|free|json] [window]\n' "$1" >&2; exit $EXIT_USAGE ;;
    *)
      if [ -z "$SUB" ]; then SUB="$1"
      elif [ -z "$WINDOW" ]; then WINDOW="$1"
      else printf 'error: unexpected argument %s\n' "$1" >&2; exit $EXIT_USAGE
      fi
      shift ;;
  esac
done
[ -n "$SUB" ] || { usage; exit $EXIT_USAGE; }

command -v node >/dev/null 2>&1 || { printf 'managandr: unknown — node is not on PATH\n' >&2; exit $EXIT_UNKNOWN; }
[ -r "$READER" ] || { printf 'managandr: unknown — reader not found at %s\n' "$READER" >&2; exit $EXIT_UNKNOWN; }

# The grant is a CONFIG input, never a build input: load the vault only if it is
# there. The reader degrades to a NAMED error when this yields no token.
if [ -z "${MANAGANDR_NO_VAULT:-}" ] && [ -z "$FIXTURE" ] && [ -z "${MANAGANDR_FIXTURE:-}" ]; then
  if vault_env="$("$ROOT/bin/hodd.sh" emit secrets/platform.env 2>/dev/null)"; then
    eval "$vault_env" 2>/dev/null || true
  fi
fi

ARGS=()
case "$SUB" in
  probe) ARGS+=(--probe) ;;
  busy|free) ARGS+=(--ask "$SUB") ;;
  json) ARGS+=() ;;
esac
[ -n "$WINDOW" ]   && ARGS+=(--window "$WINDOW")
[ -n "$NOW" ]      && ARGS+=(--now "$NOW")
[ -n "$FIXTURE" ]  && ARGS+=(--fixture "$FIXTURE")
[ -n "$CACHE" ]    && ARGS+=(--cache "$CACHE")
[ "$REFRESH" = 1 ] && ARGS+=(--refresh)
[ "$TITLES" = 1 ]  && ARGS+=(--titles)

node "$READER" "${ARGS[@]}"
rc=$?
case "$rc" in
  0)  exit $EXIT_FREE ;;
  10) exit $EXIT_BUSY ;;
  *)  exit $EXIT_UNKNOWN ;;
esac
