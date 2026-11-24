#!/usr/bin/env bash
# errand-stop.sh — Claude Code `Stop` hook: a worker cannot end an errand without answering (plan 365 R3).
# It acts only inside an errand (a worktree branch `eindri/<id>` or $YMIR_ERRAND_ID) that has a recorded return
# address; anywhere else it does nothing. Until `answer.sh guard <errand>` passes — the report written and the answer
# handed or queued — it blocks the stop and says what to run, so the worker's next turn is the report. It lets go
# on the second try (`stop_hook_active`) so a broken door can never trap a session forever.
input="$(cat 2>/dev/null)"
case "$input" in *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) exit 0 ;; esac
id="${YMIR_ERRAND_ID:-}"
if [ -z "$id" ]; then
  b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  case "$b" in eindri/*) id="${b#eindri/}" ;; esac
fi
[ -n "$id" ] || exit 0
state="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
[ -e "$state/$id.replyto" ] || exit 0
root="${YMIR_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
door="$root/bin/agents/answer.sh"
[ -x "$door" ] || door="$HOME/ymir-runtime/bin/agents/answer.sh"
[ -r "$door" ] || exit 0
why="$(bash "$door" guard "$id" 2>&1)" && exit 0
python3 -c 'import json,sys; print(json.dumps({"decision":"block","reason":"You cannot end this errand yet: "+sys.argv[1]}))' "$why"
exit 0
