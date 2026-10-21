#!/usr/bin/env bash
# logretta-panes.sh — the council, in herdr: one pane per seat, so it can be watched.
#
# Plan 92 (Lögrétta) §2.1 "in-panes": the same council as `logretta_sit`, but visible. Each
# seat gets one pane, running `pi` on that seat's model with its FIGURE's persona, and tapping
# the room under its own name (`ROOM_TAP_AGENT=<seat>`) so every word it says also lands in the
# council's record — the panes are the room you watch, the record is the room you keep.
#
# Reads `$YMIR_HOME/config/logretta-stack.yaml` (the same file `logretta_sit` reads): a seat is
# never named in this script (Rule 07).
#
# Usage:
#   bin/pi/logretta-panes.sh up [--room R]      # raise the council, one pane per seat
#   bin/pi/logretta-panes.sh status             # which seats stand, in which pane
#   bin/pi/logretta-panes.sh down               # close the council's panes
#
# Exit: 0 ok · 2 usage · 3 no stack · 4 herdr unavailable
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=bin/vault/hoard-lib.sh
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true

VERSION="1.0.0"
case "${1-}" in -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

home_or_die() {
  local h=""
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root h 2>/dev/null
  [ -n "$h" ] || h="${YMIR_HOME:-}"
  [ -n "$h" ] || { printf 'council[1]{error}: "the hoard is unresolved — set YMIR_HOME"\n' >&2; exit 3; }
  printf '%s' "$h"
}
H="$(home_or_die)"; STACK="$H/config/logretta-stack.yaml"
[ -f "$STACK" ] || { printf 'council[1]{error}: "no stack at %s" · help: "bin/pi/logretta-ensure.sh ensure"\n' "$STACK" >&2; exit 3; }
command -v herdr >/dev/null || { printf 'council[1]{error}: "herdr is absent"\n' >&2; exit 4; }

seats() {  # name<TAB>model<TAB>lens
  python3 - "$STACK" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for s in d.get("slots", []) or []:
    print(f'{s.get("name")}\t{s.get("model")}\t{s.get("lens","judge")}')
PY
}

persona() {  # <seat> → that figure's persona file, if one exists
  ls "$ROOT"/.agents/agents/"$1"-*.md "$ROOT"/.agents/agents/"$1".md 2>/dev/null | head -1
}

jget() { python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('result',{});print(r$1)" 2>/dev/null; }

cmd_up() {
  local room="the-elders"
  while [ $# -gt 0 ]; do case "$1" in --room) room=${2-}; shift 2 ;; *) shift ;; esac; done
  local out root label="${COUNCIL_LABEL:-council}"
  out=$(herdr workspace create --cwd "$ROOT" --label "$label" --no-focus 2>/dev/null) || {
    printf 'council[1]{error}: "herdr refused the workspace — is its server running?"\n' >&2; exit 4; }
  root=$(printf '%s' "$out" | jget "['root_pane']['pane_id']")
  [ -n "$root" ] || { printf 'council[1]{error}: "herdr returned no pane"\n' >&2; exit 4; }
  local first=1 pane="$root" name model lens pers
  printf 'council[1]{room,workspace}:\n  "%s","%s"\n' "$room" "$label"
  while IFS=$'\t' read -r name model lens; do
    [ -n "$name" ] || continue
    if [ "$first" = 1 ]; then
      pane="$root"; first=0
    else
      pane=$(herdr pane split "$root" --direction right --ratio 0.5 2>/dev/null | jget "['pane']['pane_id']")
      [ -n "$pane" ] || pane=$(herdr pane split "$root" --direction right 2>/dev/null | jget "['new_pane']['pane_id']")
    fi
    [ -n "$pane" ] || { printf '  "could not split for %s"\n' "$name"; continue; }
    pers="$(persona "$name")"
    herdr pane run "$pane" env ROOM_TAP_AGENT="$name" COUNCIL_LENS="$lens" pi --name "$name" \
      --model "$model" ${pers:+--append-system-prompt "$pers"} >/dev/null 2>&1
    printf '  "%s","%s","%s","%s"\n' "$name" "$pane" "$model" "$lens"
  done < <(seats)
}

cmd_status() {
  local seated
  seated=$(herdr workspace list 2>/dev/null | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for w in (d.get('result',{}).get('workspaces') or []):
    if w.get('label') == '${COUNCIL_LABEL:-council}': print(w.get('workspace_id'))
" 2>/dev/null)
  [ -n "$seated" ] || { printf 'council[2]{state,seats}:\n  "not raised",0\n'; exit 0; }
  herdr pane list 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
rows=[p for p in d.get('result',{}).get('panes',[]) if p.get('workspace_id')=='$seated']
print('council_panes[%d]{pane,cwd,agent}:' % len(rows))
for p in rows: print('  \"%s\",\"%s\",\"%s\"' % (p.get('pane_id'),p.get('foreground_cwd'),p.get('agent_status')))
"
}

cmd_down() {
  local seated
  seated=$(herdr workspace list 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('\n'.join(w.get('workspace_id') for w in (d.get('result',{}).get('workspaces') or []) if w.get('label')=='${COUNCIL_LABEL:-council}'))
" 2>/dev/null)
  [ -n "$seated" ] || { printf 'council[1]{state}:\n  "nothing raised"\n'; exit 0; }
  for w in $seated; do herdr workspace close "$w" >/dev/null 2>&1 && printf '  closed %s\n' "$w"; done
}

CMD="${1-}"; shift || true
case "$CMD" in
  up) cmd_up "$@" ;;
  status) cmd_status ;;
  down) cmd_down ;;
  *) printf 'council[1]{error}: "unknown command: %s"\n' "$CMD" >&2; exit 2 ;;
esac
