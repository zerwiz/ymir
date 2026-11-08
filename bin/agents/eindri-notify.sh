#!/usr/bin/env bash
# eindri-notify.sh — the ARM-HOLDER'S INBOX: inject one line into the session that holds the lock.
#
# WHY THIS EXISTS (the Allfather, 2026-11-08: *"why arent they injecting into your session chat? we have
# built that and its not getting used. they are writing handoff in files now instead"*). He is right:
# `report.sh` writes a report FILE and the wake queue ANNOUNCES it — but nothing puts the line into the
# chat of the session that actually holds the lock. A message that only reaches a file has not reached
# anybody; the lock holder reads panes, not shelves.
#
# THE ROAD, and there is exactly one:
#   1. the lock record names the owner pid          (~/.local/state/ymir/brokk.lock)
#   2. herdr knows which pane hosts that process    (herdr pane process-info)
#   3. herdr steering speaks a turn into it         (bin/agents/eindri-send.sh → herdr agent prompt)
# So a worker's one line arrives as a turn in the arm holder's session, which is what "inject into the
# chat window" means in this house.
#
#   eindri-notify.sh --from <name> -- "<one line>"
#   eindri-notify.sh --status                 # which pane would receive, and whether the lock owner is live
#   eindri-notify.sh --dry --from <name> -- "<one line>"   # resolve everything, inject nothing
#
# Refuses loudly when it cannot inject, and says which of the three links broke: a silent success would
# be the same fault it exists to fix. Exit: 0 injected · 1 could not inject · 2 usage.
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"

from="an errand"
line=""
while [ $# -gt 0 ]; do
  case "$1" in
    --from) from="${2-}"; shift 2 ;;
    --from=*) from="${1#--from=}"; shift ;;
    --status) status=1; shift ;;
    --dry) dry=1; shift ;;
    --) shift; line="${*:-}"; break ;;
    *) line="${line:+$line }$1"; shift ;;
  esac
done

# ── 1 · the lock record ────────────────────────────────────────────────────────────────────────────
lock="$HOME/.local/state/ymir/brokk.lock"
[ -r "$lock" ] || { printf 'eindri-notify: no lock record at %s — nobody to inject into\n' "$lock" >&2; exit 1; }
owner="$(tr -dc '0-9' < "$lock" | head -c 12)"
[ -n "$owner" ] || { printf 'eindri-notify: the lock record names no pid\n' >&2; exit 1; }

# ── 2 · the pane that hosts it ─────────────────────────────────────────────────────────────────────
pane=""
if command -v herdr >/dev/null 2>&1; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    info="$(timeout 15 herdr pane process-info --pane "$p" 2>/dev/null || true)"
    case "$info" in
      *"\"pid\": $owner"*|*"\"pid\":$owner"*|*" $owner "*) pane="$p"; break ;;
    esac
  done < <(timeout 20 herdr agent list 2>/dev/null \
            | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for a in (d.get("result") or {}).get("agents") or []:
    print(a.get("pane_id") or "")' 2>/dev/null)
fi

if [ "${status:-0}" = 1 ]; then
  alive="no"; kill -0 "$owner" 2>/dev/null && alive="yes"
  printf 'arm-holder[1]{lock_owner,alive,pane}:\n  "%s","%s","%s"\n' "$owner" "$alive" "${pane:-NOT FOUND}"
  [ -n "$pane" ] && exit 0 || exit 1
fi

[ -n "$line" ] || { printf 'usage: eindri-notify.sh --from <name> -- "<one line>"\n' >&2; exit 2; }
if [ -z "$pane" ]; then
  printf 'eindri-notify: refused — the lock owner (pid %s) hosts no pane this machine can see.\n' "$owner" >&2
  printf '  the report is on the shelf and in the wake queue; the chat injection could not happen.\n' >&2
  exit 1
fi

# ── 3 · speak it into that session ─────────────────────────────────────────────────────────────────
if [ "${dry:-0}" = 1 ]; then
  # PROVE THE ROAD WITHOUT SHOUTING (added 2026-11-08: the smoke suite ran three times and left three
  # lines in the holder's chat, which is noise in the one window that must stay readable).
  printf 'dry-inject[1]{from,pane,owner}:
  "%s","%s","%s"
' "$from" "$pane" "$owner"
  exit 0
fi

export BROKK_INJECT_MARK=1
if timeout 60 "$ROOT/bin/agents/eindri-send.sh" "$pane" "[${from}] ${line}" >/dev/null 2>&1; then
  printf 'injected[1]{from,pane,owner}:\n  "%s","%s","%s"\n' "$from" "$pane" "$owner"
  exit 0
fi
printf 'eindri-notify: refused — herdr did not accept the turn for pane %s (owner %s)\n' "$pane" "$owner" >&2
exit 1
