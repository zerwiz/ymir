#!/usr/bin/env bash
# verify-seat.sh — is this seat actually whole? FAILS LOUD when it is not.
#
# WHY (2026-10-01): on 2026-09-30 this seat had `state/.supervision-armed` sitting on disk,
# **no process holding it**, and no `.pi-gna-watch-loaded` at all — so the watch had silently
# not loaded, errands finished, and **nothing woke anyone**. Nothing failed. That is the worst
# class of fault in this house: a capability that is quietly ABSENT.
#
# So: one door, run at the end of every app start (scripts/start.sh), that PROVES the surfaces
# exist and exits NON-ZERO when one does not. It reports what is missing by name — a seat that
# cannot prove itself must say so rather than look healthy.
#
#   bin/verify-seat.sh            # verify; non-zero if anything is missing
#   bin/verify-seat.sh --quiet    # only the verdict line
#   bin/verify-seat.sh --no-exit  # report only, always 0 (for diagnostics)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUIET=0; NOEXIT=0
for a in "$@"; do
  case "$a" in
    --quiet) QUIET=1 ;;
    --no-exit) NOEXIT=1 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

MISSING=0
row() { [ "$QUIET" = 1 ] || printf '  %-22s %s\n' "$1" "$2"; }
bad() { row "$1" "MISSING — $2"; MISSING=$((MISSING + 1)); }
good() { row "$1" "ok — $2"; }

printf 'verify-seat[2]{missing,of}:\n  "%s","%s"\n' "$MISSING" "5"

# 1 · the Pi extensions are DEPLOYED (present in the global home)
EXT_DIR="${PI_EXT_DIR:-$HOME/.pi/agent/extensions}"
# The expected set is DERIVED from the source shelf, not a hand-kept list: a list here
# went stale the moment a door was added, which is how a user could install Ymir and
# never receive an extension. Every door in .pi/shared/extensions MUST be on the seat.
want_ext=()
while IFS= read -r f; do want_ext+=("$(basename "$f")"); done < <(
  ls "$ROOT/.pi/shared/extensions/"*.ts 2>/dev/null | sort
)
have=0; absent=""; broken=""
for e in "${want_ext[@]}"; do
  if [ ! -f "$EXT_DIR/$e" ]; then absent="$absent $e"; continue; fi
  have=$((have + 1))
  # DEPLOYED IS NOT LOADABLE. This check counted FILES COPIED and said "14/14 deployed"
  # while `eindri.ts` had an unclosed paren and Pi refused to start with
  # "Failed to load extension … ParseError". A file the seat copies is not a file the seat
  # can run, and the difference is the whole point of seating anything.
  if ! _ps="$(node --experimental-strip-types --input-type=module -e "
      import('node:fs').then(fs => process.stdout.write(fs.readFileSync(process.argv[1],'utf8')))
    " "$EXT_DIR/$e" 2>/dev/null)"; then
    broken="$broken $e"
    continue
  fi
  # node cannot PARSE ts, but Pi's loader strips types first. So parse the types away and
  # then check the JavaScript that results is syntactically whole.
  _js="$(printf '%s' "$_ps" | npx --yes esbuild --loader=ts --log-level=error 2>/dev/null)" \
    || broken="$broken $e"
done
[ -z "$absent" ] && [ -z "$broken" ] && good extensions "$have/${#want_ext[@]} deployed AND parsing in $EXT_DIR" \
                  || bad extensions "not deployed:$absent  |  deployed but DOES NOT PARSE:$broken  (bin/valknut-load.sh --all --global; then parse them)"

# 2 · the Gná watch actually LOADED this session (its own marker, not an arm file)
STATE="${YMIR_STATE_DIR:-}"
if [ -z "$STATE" ]; then
  ( . "$ROOT/bin/hoard-lib.sh" 2>/dev/null && hoard_state_dir STATE ) || true
fi
STATE="${STATE:-$ROOT/state}"
# THE CONDITION, NOT A FILENAME. This asked for `.pi-gna-watch-loaded` — a marker NOTHING in
# the house writes — while the watcher writes `.watch.heartbeat` with a unix timestamp, and
# that heartbeat was CURRENT to the second when this was found. So the seat reported the watch
# MISSING while it was beating. Sixth in this family: a gate asserting a named artefact
# instead of the thing the artefact stands for. Ask whether the watch is ALIVE:
#   fresh heartbeat  (now - value < WATCH_STALE_SECONDS, default 1800)
#   OR a loaded-marker, for any seat that does write one
if [ -f "$STATE/.pi-gna-watch-loaded" ]; then
  good watch-loaded "marker $(stat -c%y "$STATE/.pi-gna-watch-loaded" 2>/dev/null | cut -d' ' -f1)"
elif [ -f "$STATE/.watch.heartbeat" ]; then
  _hb="$(head -c 20 "$STATE/.watch.heartbeat" 2>/dev/null | tr -cd '0-9')"
  _now="$(date +%s)"
  _age=$(( _now - ${_hb:-0} ))
  if [ "$_age" -ge 0 ] && [ "$_age" -lt "${WATCH_STALE_SECONDS:-1800}" ]; then
    good watch-loaded "heartbeat ${_age}s old (alive; marker .pi-gna-watch-loaded is not written by this house)"
  else
    # a heartbeat from the FUTURE is unreadable, not "very old" — say which, not a huge number
    if [ "$_age" -lt 0 ]; then
      bad watch-loaded "heartbeat reads ${_age}s in the FUTURE — unreadable; the watch is not beating"
    else
      bad watch-loaded "heartbeat is ${_age}s old — STALE (over ${WATCH_STALE_SECONDS:-1800}s): the watch has stopped beating"
    fi
  fi
else
  bad watch-loaded "no heartbeat and no marker under $STATE — the watch is NOT active"
fi

# 3 · a PROCESS holds the arm (the file existing proved nothing on 2026-09-30)
# WATCHER_PIDS lets a test prove liveness with a real pid; the default is the real search.
if [ -n "${WATCHER_PIDS:-}" ]; then
  _w=0; for _p in $WATCHER_PIDS; do kill -0 "$_p" 2>/dev/null && _w=1; done
  [ "$_w" = 1 ]
# The NAMES were guessed and matched nothing that exists. Measured on 2026-10-03: the watcher
# actually runs as `python -m ymir_runtime watch run` (pid 1206), while this pattern asked for
# syn-watch|gna-watch|branch-supervision — so the seat reported "no watcher alive" while its
# heartbeat was four seconds old. Same disease as the marker it now replaced: asserting a name
# instead of the thing the name stands for. Each pattern below is a name MEASURED on this host.
elif pgrep -f "ymir_runtime watch|ymir_runtime supervise|syn-watch-arm|syn-watch\.sh|gna-watch|branch-supervision|watch-drain" >/dev/null 2>&1; then
  good watch-running "pid(s) alive: $(pgrep -f "ymir_runtime watch|syn-watch|gna-watch" | tr "\n" " " | cut -c1-60)"
else
  bad watch-running "no watcher process is alive (an arm file alone is not an arm)"
fi

# 3b · the phone gateway answers (plan 68 P1)
# A seat with a dead phone door is not whole — and the smoke is the OFFLINE one by default, so
# this row costs nothing and never depends on a model being resident.
if [ -x "$ROOT/tools/ymir-gateway/smoke.sh" ]; then
  if out_gw="$(bash "$ROOT/tools/ymir-gateway/smoke.sh" 2>&1)"; then
    good gateway "smoke answers ($(printf '%s' "$out_gw" | grep -c '","PASS"') checks)"
  else
    bad gateway "smoke FAILED — $(printf '%s' "$out_gw" | grep '"FAIL"' | head -1 | cut -c1-70)"
  fi
else
  bad gateway "no tools/ymir-gateway/smoke.sh — the phone door has no proof"
fi

# 4 · the helm names a LIVE pid
# The lock path resolves (Rule 07): env → the one the seat uses → the documented default.
LOCK="${BROKK_LOCK:-${BROKK_STATE_ROOT:-$HOME/.local/state/ymir}/brokk.lock}"
if [ -r "$LOCK" ]; then
  pid=$(head -n1 "$LOCK" 2>/dev/null | tr -dc '0-9')
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    good helm "held by a live pid ($pid)"
  else
    bad helm "the lock names '${pid:-empty}', which is not alive"
  fi
else
  bad helm "no machine lock at $LOCK"
fi

# 5 · the vault resolves and the well log is where the reader looks
# The home, resolved by THE resolver the ward names (ymir_home_root, bin/hoard-lib.sh).
# Defaults-guard refused this file for using $YMIR_HOME without calling it — correctly.
# The library is SOURCED here: calling a resolver that was never defined falls back to
# the env and quietly proves less than it claims.
# shellcheck source=bin/hoard-lib.sh
. "$ROOT/bin/hoard-lib.sh" 2>/dev/null || true
H=""
if command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root H
fi
[ -n "$H" ] || H="${YMIR_HOME:-}"
if [ -n "$H" ] && [ -d "$H/hodd/memory/well" ]; then
  good vault "resolved to $H (well log present)"
else
  bad vault "the home does not resolve, or hodd/memory/well is absent — recall and observe have nowhere to go"
fi

printf 'verify-seat[1]{verdict,missing}:\n'
if [ "$MISSING" -eq 0 ]; then
  printf '  "WHOLE","0"\n'
  [ "$NOEXIT" = 1 ] || exit 0
  exit 0
fi
printf '  "NOT WHOLE","%s"\n' "$MISSING"
printf '  a seat that cannot prove itself must say so — this is not a warning, it is a fail.\n' >&2
[ "$NOEXIT" = 1 ] && exit 0
exit 1