#!/usr/bin/env bash
# agents-status.sh — which agents are running, where, on what work, and which are idle.
#
# His word (2026-11-14): "we also need to have a registry and know what agents are running and where. What are they doing
# and not. We have a few important tasks to handle with agents on the server."
#
# An agent with no errand is not "free" — it is an unowned process holding memory (RULES/55). An errand with no agent is
# a task nobody is doing. This lists both from the backend that actually holds them (herdr first, tmux as fallback).
#
#   agents-status.sh            human list
#   agents-status.sh --yaml     the record
set -uo pipefail
mode="${1:-table}"

rows() {
  if command -v herdr >/dev/null 2>&1 && herdr agent list >/dev/null 2>&1; then
    herdr agent list 2>/dev/null | python3 -c '
import json,sys,subprocess
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
for a in d.get("result",{}).get("agents",[]):
    cwd=a.get("cwd","")
    errand=""
    for part in cwd.split("/"):
        if part and part not in ("home",): errand=part
    print("\t".join([str(a.get("pane_id","")), str(a.get("agent_status","")), cwd, errand]))
'
  elif command -v tmux >/dev/null 2>&1; then
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}	#{pane_current_command}	#{pane_current_path}' 2>/dev/null | \
      awk -F'\t' '{print $1"\t"$2"\t"$3"\t"(split($3,a,"/")?a[length(a)]:"")}'
  fi
}

if [ "$mode" = "--yaml" ]; then
  printf 'agents:\n'
  rows | while IFS=$'\t' read -r pane status cwd errand; do
    [ -z "$pane" ] && continue
    printf '  - pane: "%s"\n    status: %s\n    cwd: "%s"\n    errand: "%s"\n' "$pane" "${status:-unknown}" "$cwd" "$errand"
  done
  exit 0
fi

printf '%-10s %-12s %-28s %s\n' PANE STATUS ERRAND CWD
rows | while IFS=$'\t' read -r pane status cwd errand; do
  [ -z "$pane" ] && continue
  printf '%-10s %-12s %-28s %s\n' "$pane" "${status:-unknown}" "${errand:-?}" "$(printf '%.40s' "$cwd")"
done
