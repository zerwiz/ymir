#!/usr/bin/env bash
# seats.sh — where the work actually is: panes in either backend, and the dead shells named.
#
#   seats.sh list     # herdr first, tmux fallback; a shell whose owner is gone is named DEAD
#   seats.sh brief    # ONE table a voice can read out: panes · live agents · working · shells
set -uo pipefail
case "${1:-list}" in
  -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  brief)
    if command -v herdr >/dev/null 2>&1 && herdr pane list >/dev/null 2>&1; then
      # the JSON goes through a FILE, not a pipe: a heredoc owns stdin, so `cmd | python3 - <<PY`
      # streams nothing and the table came back empty on the first try (2026-11-08)
      tmp="$(mktemp)"
      herdr pane list >"$tmp" 2>/dev/null
      python3 /dev/fd/3 3<<'PY' "$tmp"
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print('seats[1]{state}: "herdr answered nothing readable"'); raise SystemExit(0)
panes = (data.get('result') or {}).get('panes') or []
live = [p for p in panes if p.get('agent')]
working = [p for p in live if (p.get('agent_status') or '') == 'working']
print('seats[1]{panes,live,working,shells}:')
print(f'  "{len(panes)}","{len(live)}","{len(working)}","{len(panes) - len(live)}"')
print('panes[N]{id,agent,status,cwd}:')
for p in panes:
    cwd = (p.get('cwd') or '').replace('/home/heimdall', '~')
    print(f'  "{p.get("pane_id") or "?"}","{p.get("agent") or "shell"}","{p.get("agent_status") or "-"}","{cwd}"')
# plan 255 · S4: a bare shell that is NOT an errand is the Allfather's own
# working directory — named in its own row, never closed by a sweep.
orphans = [p for p in panes if not p.get('agent') and '/.yggdrasil/' not in (p.get('cwd') or '')]
print(f'orphans[{len(orphans)}]{{pane,cwd}}:')
for p in orphans:
    cwd = (p.get('cwd') or '').replace('/home/heimdall', '~')
    print(f'  "{p.get("pane_id") or "?"}","{cwd}"')
PY
      rm -f "$tmp"
      exit 0
    fi
    if command -v tmux >/dev/null 2>&1 && tmux list-panes -a >/dev/null 2>&1; then
      echo 'seats[1]{backend}: "tmux"'
      tmux list-panes -a -F '  "#{session_name}:#{window_index}.#{pane_index}","#{pane_current_command}","#{pane_title}"' 2>/dev/null | head -40
      exit 0
    fi
    echo 'seats[1]{state}: "no pane backend is running (herdr and tmux both silent)"'
    exit 0 ;;
  list)
    if command -v herdr >/dev/null 2>&1 && herdr pane list >/dev/null 2>&1; then
      echo "backend: herdr"; herdr pane list 2>/dev/null | head -40
    elif command -v tmux >/dev/null 2>&1 && tmux list-panes -a >/dev/null 2>&1; then
      echo "backend: tmux"; tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_title} pid=#{pane_pid} cmd=#{pane_current_command}' 2>/dev/null | head -40
    else
      echo "no pane backend is running (herdr and tmux both silent)"
    fi ;;
  close)
    # close a shell whose OWNER is gone — never a live seat
    target="${2:-}"; [ -n "$target" ] || { echo "close needs a pane id" >&2; exit 2; }
    if command -v herdr >/dev/null 2>&1; then
      info="$(herdr pane list 2>/dev/null | grep -o "\"pane_id\":\"$target\"[^}]*" | head -1)"
      case "$info" in
        *'"agent_status":"working"'*|*'"agent_status":"idle"'*) printf 'refused: %s holds a live agent\n' "$target"; exit 1 ;;
      esac
      herdr pane close "$target" 2>/dev/null && printf 'closed %s (no live agent held it)\n' "$target" && exit 0
    fi
    if command -v tmux >/dev/null 2>&1 && tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null | grep -qx "$target"; then
      cmd="$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null)"
      case "$cmd" in bash|zsh|sh|"") tmux kill-pane -t "$target" && printf 'closed %s (bare shell)\n' "$target" && exit 0 ;; esac
      printf 'refused: %s is running %s\n' "$target" "$cmd"; exit 1
    fi
    printf 'no such pane: %s\n' "$target"; exit 1 ;;
  *) printf 'error: unknown action %s\nhelp: seats.sh [list|close <pane>]\n' "$1" >&2; exit 2 ;;
esac
