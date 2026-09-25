#!/usr/bin/env bash
# nidhogg.sh — Níðhöggr, the gnawer at the root. The hallucination finder:
# catch a worker that is SPINNING, not merely alive.
#
# Níðhöggr gnaws at Yggdrasil's root endlessly and accomplishes nothing — the
# perfect image of a model repeating the same fruitless action forever. This
# tool names the gnawing and breaks it.
#
# Every other guard asks "is it alive?" (Sýn watches for silence, the arm
# watches for the agent leaving `working`). None asks "is it going anywhere?" A
# looping worker is still `working` forever, so the liveness checks read true
# while the machine burns. This is the missing question.
#
# A hallucination loop has a fingerprint:
#   repeat : the same command recurs            (the strongest, cheapest signal)
#   stall  : the pane stops changing            (same fingerprint across scans)
#   burn   : cache reads climb while output does not
#
# Usage:
#   nidhogg.sh scan [--threshold N] [<agent>...]   # all seated agents if none named
#   nidhogg.sh break <agent> [--message "…"]       # rung 1: interrupt + steer
#   nidhogg.sh watch [--interval N] [--break]      # scan on a cycle
#   nidhogg.sh --version
#
# Exit: 0 clean, 3 a loop was found, 1 error, 2 usage. (3 is the trip signal,
# the same convention eindri-seen uses for its condition half.)
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The records live outside the code tree (Rule 04): the operator's home, never
# the packaged tree that an upgrade replaces.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
if command -v hoard_state_dir >/dev/null 2>&1; then
  hoard_state_dir YMIR_STATE_DIR
fi
# Resolve-or-refuse. The code tree's state/ is never a fallback: that fallback IS
# the drift the plan's purity row exists to catch, and the operator's runtime state
# (logs, locks, pids) belongs in the home they chose, or the next upgrade erases it.
STATE="${BROKK_STATE_OVERRIDE:-${YMIR_STATE_DIR:-}}"
if [ -z "$STATE" ]; then
  printf 'error: the state dir did not resolve\nhelp: source bin/hoard-lib.sh (it resolves the home), or set BROKK_STATE_OVERRIDE\n' >&2
  exit 1
fi

# Thresholds resolve from config with one documented default (Rule 07).
THRESHOLD="${LOOP_REPEAT_N:-3}"
STALL_TURNS="${LOOP_STALL_TURNS:-2}"
INTERVAL="${LOOP_POLL_SECONDS:-20}"
READ_LINES="${LOOP_READ_LINES:-500}"
FP_DIR="$STATE/.nidhogg"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-scan}"; shift || true

have() { command -v "$1" >/dev/null 2>&1; }

# The seated agents, one per line. herdr is the roster.
seated_agents() {
  have herdr || return 1
  herdr agent list 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    for a in d["result"]["agents"]:
        print(a.get("name",""))
except Exception:
    pass' 2>/dev/null
}

agent_status() {  # <agent>
  herdr agent list 2>/dev/null | python3 -c '
import json,sys
want=sys.argv[1]
try:
    for a in json.load(sys.stdin)["result"]["agents"]:
        if a.get("name")==want: print(a.get("agent_status","unknown")); break
except Exception: pass' "$1" 2>/dev/null
}

# The agent's pane. A generous window on purpose: herdr's default read shows
# only the recent tail, and a loop's repeats scroll out of it — the whole point
# is to count repeats, so ask for the scrollback.
pane_of() { herdr agent read "$1" --lines "$READ_LINES" 2>/dev/null || true; }

# Extract the command lines a coding agent ran. herdr renders them with a
# leading "$"; everything else is prose or output.
commands_of() {  # <pane-text> -> one command per line, whitespace-normalized
  grep -E '^[[:space:]]*\$ ' 2>/dev/null | sed -E 's/^[[:space:]]*\$ //; s/[[:space:]]+$//'
}

# The most-repeated command and its count, from the command stream.
# Prints "<count> <command>" for the worst offender, or nothing.
worst_repeat() {  # <pane-text>
  commands_of | sort | uniq -c | sort -rn | head -n 1 | sed -E 's/^[[:space:]]*([0-9]+)[[:space:]]+/\1 /'
}

# A fingerprint of the pane's tail: the last 12 non-blank lines, hashed. If it
# does not change between scans, the worker is stalled — it may be looping on a
# belief rather than on a command, which the repeat signal alone would miss.
fingerprint_of() {  # <pane-text>
  printf '%s' "$1" | grep -v '^[[:space:]]*$' | tail -n 12 \
    | { command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256; } \
    | cut -d' ' -f1
}

scan_one() {  # <agent> -> prints a TOON row; sets SCAN_VERDICT
  local agent=$1 pane status worst count fp fpfile prev stall verdict fp_text
  pane="$(pane_of "$agent")"
  status="$(agent_status "$agent")"
  [ -n "$pane" ] || pane=""
  worst="$(printf '%s' "$pane" | worst_repeat)"
  count="${worst%% *}"; fp_text="${worst#* }"
  [ "$worst" = "" ] && count=0

  fp="$(fingerprint_of "$pane")"
  fpfile="$FP_DIR/$agent.fp"
  mkdir -p "$FP_DIR" 2>/dev/null || true
  prev=""
  [ -r "$fpfile" ] && prev="$(cat "$fpfile" 2>/dev/null)"
  stall=no
  [ -n "$prev" ] && [ "$prev" = "$fp" ] && stall=yes
  printf '%s\n' "$fp" >"$fpfile" 2>/dev/null || true

  verdict="clean"
  if [ "$count" -ge "$THRESHOLD" ] 2>/dev/null; then
    verdict="LOOP — the same command ran $count times"
  elif [ "$stall" = "yes" ] && [ "$status" = "working" ]; then
    verdict="STALL — the pane is unchanged while the worker is working"
  fi
  [ "$verdict" = "clean" ] || SCAN_VERDICT=loop

  # TOON: keep the fingerprint short so a long command does not swamp the row.
  local short="${fp_text:0:70}"
  printf '  "%s","%s",%s,%s,"%s","%s"\n' \
    "$agent" "${status:-unknown}" "$count" "$THRESHOLD" "$verdict" "$short"
}

cmd_scan() {
  local agents=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --threshold) THRESHOLD="${2-}"; shift 2 ;;
      --threshold=*) THRESHOLD="${1#--threshold=}"; shift ;;
      -*) shift ;;
      *) agents+=("$1"); shift ;;
    esac
  done
  if [ ${#agents[@]} -eq 0 ]; then
    while IFS= read -r a; do [ -n "$a" ] && agents+=("$a"); done < <(seated_agents)
  fi
  [ ${#agents[@]} -gt 0 ] || { printf 'nidhogg[1]{agents}:\n  "none","no seated agents"\n'; exit 0; }

  SCAN_VERDICT=clean
  printf 'nidhogg[%s]{agent,status,repeats,threshold,verdict,last_repeated}:\n' "${#agents[@]}"
  local a
  for a in "${agents[@]}"; do scan_one "$a"; done
  [ "$SCAN_VERDICT" = "loop" ] && exit 3
  exit 0
}

# Rung 1 of the ladder: interrupt and steer. Never destructive, never silent.
cmd_break() {
  local agent="" msg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --message) msg="${2-}"; shift 2 ;;
      --message=*) msg="${1#--message=}"; shift ;;
      -*) shift ;;
      *) [ -z "$agent" ] && agent="$1"; shift ;;
    esac
  done
  [ -n "$agent" ] || { printf 'error: break needs an agent\n' >&2; exit 2; }
  [ -n "$msg" ] || msg="STOP — you are in a loop. You are repeating the same command and learning nothing from it. Break the belief, not the command. State what you know, do the one thing that changes the state, and report. Do not repeat the command."
  have herdr || { printf 'error: herdr not on PATH\n' >&2; exit 1; }
  herdr agent send-keys "$agent" esc >/dev/null 2>&1 || true
  sleep 2
  if herdr agent prompt "$agent" "$msg" >/dev/null 2>&1; then
    printf 'nidhogg[1]{agent,action,result}:\n  "%s","break","steered"\n' "$agent"
    exit 0
  fi
  printf 'nidhogg[1]{agent,action,result}:\n  "%s","break","failed — the pane did not take the steer"\n' "$agent"
  exit 1
}

cmd_watch() {
  local do_break=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --interval) INTERVAL="${2-}"; shift 2 ;;
      --interval=*) INTERVAL="${1#--interval=}"; shift ;;
      --threshold) THRESHOLD="${2-}"; shift 2 ;;
      --threshold=*) THRESHOLD="${1#--threshold=}"; shift ;;
      --break) do_break=1; shift ;;
      *) shift ;;
    esac
  done
  printf 'nidhogg[1]{watch,interval,threshold,auto_break}:\n  "on",%s,%s,"%s"\n' \
    "$INTERVAL" "$THRESHOLD" "$([ "$do_break" = 1 ] && echo yes || echo no)"
  local rc=0
  while :; do
    cmd_scan || rc=$?
    if [ "$rc" = "3" ] && [ "$do_break" = "1" ]; then
      local a
      while IFS= read -r a; do
        [ -n "$a" ] && cmd_break "$a" >/dev/null 2>&1 || true
      done < <(seated_agents)
    fi
    rc=0
    sleep "$INTERVAL"
  done
}

case "$ACTION" in
  scan)  cmd_scan "$@" ;;
  break) cmd_break "$@" ;;
  watch) cmd_watch "$@" ;;
  *) printf 'error: unknown action %s (scan|break|watch)\n' "$ACTION" >&2; exit 2 ;;
esac
