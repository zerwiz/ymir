#!/usr/bin/env bash
# release-services.sh — which long-running services run from a RELEASE, and whether that release is the pin.
#
# A release flip moves one link (`releases/current`), and every service that was
# raised from the pin before the flip keeps answering from the release it started
# in — the gate API and the SPA served `e713188ca4e2` for eight hours after the pin
# moved (plan 275 item 27). This door names those services, says which release each
# one is actually running from (measured from the process's own cwd, never guessed),
# and restarts them after a flip.
#
#   release-services.sh list                    every service that runs from a release (one name a line)
#   release-services.sh status [--toon|--json]  each service: state, pid, release, pin, on-pin, why
#   release-services.sh restart [--only-stale] [--dry-run]
#                                               restart the ACTIVE ones (a service already stopped is
#                                               reported, not raised); --only-stale skips the ones on the pin
#
# Which services: `.agents/config/units.yaml` through `bin/engine/units.sh list --restart`
# — the one register of every Ymir unit, so a new service joins this door by being
# registered, never by being added to a second list here (plan 269, Rule 07).
#
# Test seams: YMIR_UNITS_NO_SYSTEMCTL=1 (no systemctl), YMIR_RELEASE_SERVICES_ROOT (the tree to read the
# register from), YMIR_RUNTIME_DIR / YMIR_RELEASES (the pin and the release shelf).
set -uo pipefail

SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${YMIR_RELEASE_SERVICES_ROOT:-$(CDPATH='' cd "$SELF/../.." && pwd)}"
BASE="${YMIR_RELEASES:-${XDG_DATA_HOME:-$HOME/.local/share}/ymir}"
CUR="$BASE/current"
PIN="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
MODE="toon"

say() { printf '%s\n' "$*"; }

# --- the services, from the one register -----------------------------------
list_units() {
  bash "$ROOT/bin/engine/units.sh" list --restart 2>/dev/null | grep -E '\.service$' | sort -u
}

unit_field() {  # <unit> <property> — one property of one unit (systemctl show)
  systemctl --user show "$1" -p "$2" --value 2>/dev/null | head -1
}

# --- the release a process actually runs from ------------------------------
# A process's cwd is a RESOLVED path: a service raised through the pin while the
# pin pointed at releases/abcdef stores releases/abcdef, so the kernel's own record
# is the honest answer, never a re-resolution through today's link.
proc_release() {  # <pid> → a release sha, or empty
  local pid="$1" cwd cmd t
  [ -n "$pid" ] && [ "$pid" != 0 ] || return 0
  cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null)"
  cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
  for t in "$cwd" $cmd; do
    case "$t" in
      */releases/*) t="${t#*/releases/}"; printf '%s' "${t%%/*}"; return 0 ;;
    esac
  done
  # a path through the pin cannot say WHICH release it read; the caller compares times
  return 0
}

release_built() {  # <sha|dir> → epoch the release was proved/built (0 when unknown)
  local d="$1" m=""
  case "$d" in
    /*) : ;;
    *) d="$BASE/releases/$d" ;;
  esac
  for m in "$d/.release-proved" "$d/.release-adopted"; do
    [ -f "$m" ] && { stat -c %Y "$m" 2>/dev/null; return 0; }
  done
  stat -c %Y "$d" 2>/dev/null || echo 0
}

pin_sha() {
  local d; d="$(readlink -f "$CUR" 2>/dev/null || echo '')"
  if [ -n "$d" ]; then basename "$d"; return; fi
  d="$(readlink -f "$PIN" 2>/dev/null || echo '')"
  [ -n "$d" ] && basename "$d"
}

rows() {  # prints: unit|state|pid|release|on_pin|started|why
  local pin sha u state pid started rel built onpin why
  pin="$(pin_sha)"; sha="${pin:-unknown}"
  for u in $(list_units); do
    state="$(unit_field "$u" ActiveState)"; [ -n "$state" ] || state="absent"
    pid="$(unit_field "$u" MainPID)"; [ -n "$pid" ] || pid=0
    started="$(unit_field "$u" ExecMainStartTimestamp)"
    rel="$(proc_release "$pid")"
    onpin=0; why=""
    if [ -z "$pid" ] || [ "$pid" = 0 ] || [ "$state" != active ]; then
      onpin=-1
      if [ "$state" != active ]; then why="not running"; else why="active without a main pid"; fi
    elif [ -n "$rel" ]; then
      if [ "$rel" = "$pin" ]; then onpin=1; why="on the pin"; else why="started from $rel"; fi
    else
      # no release in its cwd or command line: it reads through the pin today, so
      # the honest question is whether it STARTED before this release existed.
      built="$(release_built "$sha")"
      local st; st="$(date -d "$started" +%s 2>/dev/null || echo 0)"
      [ "$built" = 0 ] && built=0
      if [ "${st:-0}" -gt 0 ] && [ "${built:-0}" -gt 0 ] && [ "${st:-0}" -lt "$built" ]; then
        why="started before $sha was built"
      else
        onpin=1; why="reads through the pin"
      fi
    fi
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$u" "$state" "$pid" "${rel:-pin}" "$onpin" "${started:-}" "$why"
  done
}

cmd_status() {
  local mode="${1:-$MODE}"
  if [ "$mode" = json ]; then
    rows | python3 -c '
import json,sys
out=[]
for line in sys.stdin:
    line=line.rstrip("\n")
    if not line: continue
    unit,state,pid,rel,onpin,started,why=line.split("|")
    out.append({"unit":unit,"state":state,"pid":int(pid or 0),"release":rel,
                "onPin":onpin=="1","running":state=="active","started":started,"why":why})
print(json.dumps({"pin":sys.argv[1],"services":out}))
' "$(pin_sha)"
    return 0
  fi
  local n; n="$(rows | grep -c . || true)"
  say "release-services[$n]{unit,state,pid,release,on_pin,started,why}:"
  rows | while IFS='|' read -r unit state pid rel onpin started why; do
    printf '  "%s","%s","%s","%s","%s","%s","%s"\n' "$unit" "$state" "$pid" "$rel" "$onpin" "$started" "$why"
  done
  local p; p="$(pin_sha)"
  say "pin: ${p:-unknown}"
}

cmd_restart() {
  local only_stale=0 dry=0 u
  while [ $# -gt 0 ]; do case "$1" in
    --only-stale) only_stale=1; shift ;;
    --dry-run) dry=1; shift ;;
    *) shift ;;
  esac; done
  local pin; pin="$(pin_sha)"
  local restarted=""; local skipped=""
  rows | while IFS='|' read -r u state pid rel onpin started why; do
    if [ "$state" != active ]; then say "  \"$u\",\"skipped\",\"$why\""; continue; fi
    if [ "$only_stale" = 1 ] && [ "$onpin" = 1 ]; then say "  \"$u\",\"current\",\"on the pin already\""; continue; fi
    if [ "$dry" = 1 ]; then say "  \"$u\",\"would-restart\",\"$why\""; continue; fi
    if systemctl --user restart "$u" 2>/dev/null; then
      say "  \"$u\",\"restarted\",\"was $rel\""
    else
      say "  \"$u\",\"FAIL\",\"systemctl refused the restart\""
    fi
  done
  return 0
}

case "${1:-status}" in
  list) list_units ;;
  status) shift || true; [ "${1:-}" = --json ] && MODE=json; cmd_status "$MODE" ;;
  restart) shift || true; cmd_restart "$@" ;;
  -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
