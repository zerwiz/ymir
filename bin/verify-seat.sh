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
have=0; absent=""
for e in "${want_ext[@]}"; do
  [ -f "$EXT_DIR/$e" ] && have=$((have + 1)) || absent="$absent $e"
done
[ -z "$absent" ] && good extensions "$have/${#want_ext[@]} deployed in $EXT_DIR" \
                  || bad extensions "not deployed:$absent  (bin/valknut-load.sh --all --global)"

# 2 · the Gná watch actually LOADED this session (its own marker, not an arm file)
STATE="${YMIR_STATE_DIR:-}"
if [ -z "$STATE" ]; then
  ( . "$ROOT/bin/hoard-lib.sh" 2>/dev/null && hoard_state_dir STATE ) || true
fi
STATE="${STATE:-$ROOT/state}"
if [ -f "$STATE/.pi-gna-watch-loaded" ]; then
  good watch-loaded "$(stat -c%y "$STATE/.pi-gna-watch-loaded" 2>/dev/null | cut -d' ' -f1)"
else
  bad watch-loaded "no .pi-gna-watch-loaded — the watch is NOT active in this session"
fi

# 3 · a PROCESS holds the arm (the file existing proved nothing on 2026-09-30)
# WATCHER_PIDS lets a test prove liveness with a real pid; the default is the real search.
if [ -n "${WATCHER_PIDS:-}" ]; then
  _w=0; for _p in $WATCHER_PIDS; do kill -0 "$_p" 2>/dev/null && _w=1; done
  [ "$_w" = 1 ]
elif pgrep -f "syn-watch|gna-watch|branch-supervision" >/dev/null 2>&1; then
  good watch-running "pid(s) alive: ${WATCHER_PIDS}"
else
  bad watch-running "no watcher process is alive (an arm file alone is not an arm)"
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