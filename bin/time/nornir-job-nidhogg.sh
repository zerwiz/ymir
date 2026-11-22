#!/usr/bin/env bash
# nornir-job-nidhogg.sh — Níðhöggr on the clock (plan 350, part B4).
#
# Níðhöggr was built and wired to nothing: the gate register said "a human or a cron row must run
# it", and none did. This row is that clock. One pass, never a loop of its own:
#
#   1. `nidhogg.sh scan` over every seated agent on this machine. An agent at LOOP or STALL is broken
#      at rung 1 (`nidhogg.sh break`: interrupt and steer — never destructive) unless NIDHOGG_BREAK=off.
#   2. `nidhogg.sh commits --json` over every repository a recent errand names (and NIDHOGG_REPOS).
#   3. Each loop found is told to the arm holder ONCE, through the Veil (bin/agents/veil.sh send
#      --kind finding), so it carries an id the holder answers with RECEIVED.
#   4. The last run is stamped in <state>/nidhogg/last-run.json, which the trouble panel reads: a
#      stamp older than its line is a red (plan 339's alarms), so a clock that stopped is seen.
#
# A clean fleet is silent: the stamp moves, nothing is told.
# Exit: 0 clean · 3 a loop was found (and told) · 1 the door failed.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
case "${1:-}" in -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
STATE="${BROKK_STATE_OVERRIDE:-${YMIR_STATE_DIR:-}}"
if [ -z "$STATE" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && hoard_state_dir STATE 2>/dev/null
fi
[ -n "${STATE:-}" ] || { printf 'nidhogg-job: the state dir did not resolve\n' >&2; exit 1; }
NID="${NIDHOGG_DOOR:-$ROOT/bin/gates/nidhogg.sh}"
VEIL="${NIDHOGG_VEIL:-$ROOT/bin/agents/veil.sh}"
[ -x "$NID" ] || { printf 'nidhogg-job: Níðhöggr is missing at %s\n' "$NID" >&2; exit 1; }
DIR="$STATE/nidhogg"; mkdir -p "$DIR"
TOLD="$DIR/told"; touch "$TOLD"
host="$(hostname -s 2>/dev/null || uname -n)"

tell_once() {  # <key> <text>
  local key=$1 text=$2
  grep -qxF -- "$key" "$TOLD" && return 0
  if [ -x "$VEIL" ] && BROKK_STATE_OVERRIDE="$STATE" "$VEIL" send --from "script Níðhöggr ($host)" --kind finding "$text" >/dev/null 2>&1; then
    printf '%s\n' "$key" >>"$TOLD"
  else
    printf 'nidhogg-job: the finding could not be told now (it is tried again next run): %s\n' "$text" >&2
  fi
}

# 1 · the panes
scan_out="$(timeout 300 bash "$NID" scan 2>&1)"; scan_rc=$?
agent_loops=0
while IFS= read -r line; do
  agent="$(printf '%s' "$line" | sed -n 's/^  "\([^"]*\)","[^"]*",[0-9]*,[0-9]*,"\(LOOP\|STALL\)[^"]*".*/\1/p')"
  [ -n "$agent" ] || continue
  agent_loops=$((agent_loops + 1))
  verdict="$(printf '%s' "$line" | sed -n 's/^  "[^"]*","[^"]*",[0-9]*,[0-9]*,"\([^"]*\)".*/\1/p')"
  broke="not broken (NIDHOGG_BREAK=off)"
  if [ "${NIDHOGG_BREAK:-on}" != off ]; then
    if timeout 60 bash "$NID" break "$agent" >/dev/null 2>&1; then broke="broken at rung 1 (interrupted and steered)"; else broke="the break failed"; fi
  fi
  tell_once "agent:$agent:$(date +%Y%m%d%H)" "Níðhöggr on $host: $agent — $verdict; $broke. Read it: herdr agent read $agent"
done <<<"$scan_out"

# 2 · the branches
repos=()
while IFS= read -r p; do [ -n "$p" ] && [ -d "$p" ] && repos+=(--repo "$p"); done < <(
  { _nr="${NIDHOGG_REPOS:-}"; printf '%s\n' ${_nr//:/ }
    find "$STATE" -maxdepth 1 -name '*.meta' -mtime -7 -exec sed -n 's/^project=//p' {} + 2>/dev/null; } | sort -u)
commit_loops=0; commits_rc=0
if [ "${#repos[@]}" -gt 0 ]; then
  cj="$(timeout 300 bash "$NID" commits --json "${repos[@]}" 2>/dev/null)"; commits_rc=$?
  while IFS=$'\t' read -r branch count subject; do
    [ -n "$branch" ] || continue
    commit_loops=$((commit_loops + 1))
    tell_once "commit:$branch:$subject" "Níðhöggr on $host: '$subject' was committed $count times in an hour on $branch — a writer is looping; stop it"
  done < <([ -n "${cj:-}" ] || cj="{}"; printf '%s' "$cj" | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: d = {}
for l in d.get("loops") or []:
    print("\t".join([" ".join(l.get("branches") or [l.get("branch", "")]), str(l.get("count", "")), l.get("subject", "")]))')
fi

# 3 · the stamp the trouble panel reads
python3 - "$DIR/last-run.json" "$host" "$scan_rc" "$commits_rc" "$agent_loops" "$commit_loops" "$((${#repos[@]} / 2))" <<'PY'
import json, os, sys, time
path, host, scan_rc, commits_rc, a, c, repos = sys.argv[1:]
tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump({"ts": int(time.time()), "host": host, "scan_rc": int(scan_rc), "commits_rc": int(commits_rc),
               "agent_loops": int(a), "commit_loops": int(c), "repos": int(repos)}, fh)
os.replace(tmp, path)
PY
printf 'nidhogg-job[1]{host,agent_loops,commit_loops,repos,stamp}:\n  "%s",%s,%s,%s,"%s"\n' \
  "$host" "$agent_loops" "$commit_loops" "$((${#repos[@]} / 2))" "$DIR/last-run.json"
[ $((agent_loops + commit_loops)) -gt 0 ] && exit 3
exit 0
