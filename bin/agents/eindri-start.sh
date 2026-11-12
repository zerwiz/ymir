#!/usr/bin/env bash
# eindri-start.sh — start an Eindri as the Allfather asks. One command.
#
#   ensure backend -> classify the role -> seat the smith -> record -> report
#
# A seat is attempted on herdr (the Þjazi backend); when the herdr CLI cannot
# seat (no `hdr`, or a herdr without `agent start`), it falls back to tmux — the
# verified sibling — so an agent always starts. Galdr-style TOON.
#
# Usage:
#   eindri-start.sh "<request>" [--role <name>] [--pane|--tab|--space] [--kind pi|opencode|claude]
#   eindri-start.sh "<request>" --id <task-id> [--project <dir>] [--role <name>] [--kind pi|opencode|claude]
#       # --id names a real errand and hands it to the engine
#       # (src/ymir_runtime/): a Yggdrasil worktree, a recorded seat, a
#       # heartbeat. Without --id the ordinary road below seats the agent.
#   eindri-start.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
hoard_settings_dir YMIR_SETTINGS_DIR
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
SEATS="$STATE/herdr-seats"
SESSION="${YMIR_HERDR_SESSION:-brokk}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

REQ=""; ROLE=""; SEAT=""; MODEL=""; KIND="${YMIR_HERDR_KIND:-pi}"; MAIN=""; TASK_ID=""; PROJECT_DIR=""; KIND_EXPLICIT=""; MODEL_EXPLICIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE=${2-}; shift 2 ;;
    --kind) KIND=${2-}; KIND_EXPLICIT=$KIND; shift 2 ;;
    --model) MODEL=${2-}; MODEL_EXPLICIT=$MODEL; shift 2 ;;
    --id) TASK_ID=${2-}; shift 2 ;;
    --project) PROJECT_DIR=${2-}; shift 2 ;;
    --main) MAIN="--main"; shift ;;
    --space) SEAT="--space"; shift ;;
    --tab) SEAT="--tab"; shift ;;
    --pane) SEAT="--pane"; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/agents/eindri-start.sh "<request>" [--id <task-id>] [--role <name>] [--pane|--tab|--space] [--kind pi|opencode|claude]\n' "$1" >&2; exit 2 ;;
    *) [ -z "$REQ" ] && REQ="$1" || REQ="$REQ $1"; shift ;;
  esac
done
[ -n "$REQ" ] || { printf 'error: eindri-start needs a request\nhelp: bin/agents/eindri-start.sh "build the login page"\n' >&2; exit 2; }

# 1. Backend: ensure herdr (or a usable backend) exists.
[ -x "$SCRIPT_DIR/../seat/herdr-ensure.sh" ] && "$SCRIPT_DIR/../seat/herdr-ensure.sh" ensure --install >/dev/null 2>&1 || true

# 2. The right smith for the request.
if [ -z "$ROLE" ] && [ -x "$SCRIPT_DIR/eindri-role.sh" ]; then
  ROLE="$("$SCRIPT_DIR/eindri-role.sh" choose "$REQ" 2>/dev/null | sed -n '2p' | sed -E 's/^ *"([^"]+)".*/\1/')"
fi
ROLE="${ROLE:-eindri}"
SLUG="$(printf '%s' "$REQ" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed -E 's/^-|-$//g' | cut -c1-24)"
LABEL="${ROLE}-${SLUG:-task}"

# 2b. WHICH MODEL — resolved for the ROLE, by the one resolver, and never silently.
# Measured 2026-11-10: without `--model` the road fell through to whatever the
# launcher defaulted to, which was brokk's row for every errand — a smith ran on the
# counsellor's model, and a machine overlay could pin a LOCAL model for a worker
# without a word said. The order of authority is bin/model/agent-model.sh's (the ONE
# resolver): explicit --model, then YMIR_<AGENT>_MODEL, then the machine overlay, then
# the fleet's agents.yaml, then the tier. This door only ASKS it, and records who
# answered.
MODEL_SOURCE=""; MODEL_NOTE=""
if [ -z "$MODEL" ] && [ -x "$SCRIPT_DIR/../model/agent-model.sh" ]; then
  resolved="$("$SCRIPT_DIR/../model/agent-model.sh" "$ROLE" --json 2>/dev/null || true)"
  if [ -n "$resolved" ]; then
    MODEL="$(printf '%s' "$resolved" | sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    MODEL_SOURCE="$(printf '%s' "$resolved" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  fi
fi
[ -n "$MODEL_SOURCE" ] || { [ -n "$MODEL" ] && MODEL_SOURCE="explicit --model" || MODEL_SOURCE="unresolved"; }
# A machine overlay that pins a LOCAL model for an errand is said out loud: the
# overlay is this machine's word, and a worker on a local rail is a fact the
# Allfather — and the arm — must be able to see without reading a config.
case "$MODEL_SOURCE" in
  *overlay*)
    lprov="$(sed -n 's/^local_providers:[[:space:]]*\[\(.*\)\].*/\1/p' "$YMIR_SETTINGS_DIR/agents.yaml" 2>/dev/null | tr ',' '\n' | tr -d ' \"' | paste -sd'|' -)"
    if [ -n "$lprov" ] && printf '%s' "$MODEL" | grep -qE "^(${lprov})/"; then
      MODEL_NOTE="a machine overlay ($MODEL_SOURCE) pinned a LOCAL model for this errand"
    else
      MODEL_NOTE="chosen by the machine overlay ($MODEL_SOURCE)"
    fi ;;
  *fleet*|*agents.yaml*) MODEL_NOTE="chosen by the fleet's agents.yaml" ;;
  *explicit*)            MODEL_NOTE="the operator's --model" ;;
  *)                     MODEL_NOTE="$MODEL_SOURCE" ;;
esac

# 2c. Claude serves Anthropic models only. The fleet's agents.yaml names a provider/model token for
# every role, so `--kind claude` without `--model` used to carry that token to the engine and was
# refused (measured 2026-11-12). A token the operator did NOT type is dropped for an Anthropic
# alias; one he typed is still refused downstream, loudly.
if [ "$KIND" = claude ] && [ -z "$MODEL_EXPLICIT" ]; then
  case "$MODEL" in
    */*|"") MODEL="${YMIR_CLAUDE_DEFAULT_MODEL:-sonnet}"; MODEL_SOURCE="default Anthropic alias for --kind claude"
            MODEL_NOTE="the Anthropic alias claude serves — the fleet's provider/model token belongs to pi or opencode" ;;
  esac
fi

# 3. The engine owns the errand when the caller names one (plan 58, Phase 1).
#    With --id an errand is a real seat — worktree, harness, record, heartbeat.
#    A seat hint (--pane/--tab/--space/--main) is the old road's grain, so those
#    callers keep the road below; YMIR_ENGINE=off skips the handoff entirely.
if [ -n "$TASK_ID" ] && [ -z "$SEAT" ] && [ -z "$MAIN" ] \
   && [ "${YMIR_ENGINE:-auto}" != "off" ] && [ -x "$SCRIPT_DIR/../engine/ymir-engine.sh" ]; then
  PROJECT_DIR="${PROJECT_DIR:-$PWD}"
  engine_args=(seat "$TASK_ID" --project "$PROJECT_DIR" --harness "$KIND" --request "$REQ" --role "$ROLE")
  if [ -n "$MODEL" ]; then engine_args+=(--model "$MODEL"); fi
  engine_rc=0
  engine_out="$("$SCRIPT_DIR/../engine/ymir-engine.sh" "${engine_args[@]}")" || engine_rc=$?
  if [ "$engine_rc" -eq 0 ]; then
    printf '%s' "$engine_out"
    printf 'eindri-start[1]{role,seat,a2a,request,label}:\n  "%s","engine","none","%s","%s"\n' "$ROLE" "$REQ" "$LABEL"
    exit 0
  fi
  if [ "$engine_rc" -ne 4 ]; then
    printf 'error: the engine failed to seat %s (exit %s) — the old road was NOT run, because a half-seat is worse than none\nhelp: bin/engine/ymir-engine.sh seat %s --project %s\n' \
      "$TASK_ID" "$engine_rc" "$TASK_ID" "$PROJECT_DIR" >&2
    exit 1
  fi
  # The ordinary road seats pi or opencode only. When the caller asked for any other
  # harness (claude, or a raw launch command), seating "the ordinary way" silently
  # REPLACED it — measured 2026-11-11: a Claude errand the engine declined came up as
  # an idle pi named mimir (plan 239 P5e). A swapped harness is a half-seat; refuse.
  case "$KIND" in
    pi|opencode) ;;
    *)
      printf 'error: the engine declined %s and the ordinary road cannot seat harness %s — refused rather than seating a different harness\nhelp: fix the reason above (e.g. give the request a "# Task" section) and retry\n' "$TASK_ID" "$KIND" >&2
      exit 1 ;;
  esac
  printf 'engine: cannot own %s — seating the ordinary way\n' "$TASK_ID" >&2
fi

mkdir -p "$STATE"

# 3. Seat: herdr first, tmux fallback — always produce a seat.
#    rc 3 from herdr-run means "not worth a smith" — report it, do NOT fake a seat.
seat="none"; refuse=0; rc=0
if [ -x "$SCRIPT_DIR/../seat/herdr-run.sh" ]; then
  "$SCRIPT_DIR/../seat/herdr-run.sh" eindri $SEAT $MAIN ${KIND_EXPLICIT:+--kind "$KIND_EXPLICIT"} ${MODEL:+--model "$MODEL"} "$ROLE" -- "$REQ" >/dev/null 2>&1 || rc=$?
fi
if [ "$rc" = 0 ]; then
  seat="herdr"
elif [ "$rc" = 3 ]; then
  seat="none"; refuse=1
else
  command -v tmux >/dev/null 2>&1 || { printf 'eindri-start[1]{role,seat,request}:\n  "%s","none","%s"\n' "$ROLE" "$REQ"; printf 'error: no seat — herdr cannot seat and tmux is absent\n' >&2; exit 1; }
  tmux has-session -t "$SESSION" 2>/dev/null || tmux new-session -d -s "$SESSION" -n shell
  # The tmux fallback seats the same worker the herdr road does (plan 262): a bare `exec opencode`
  # started empty — no model, no brief — and sat idle. The shape comes from the launcher, never here.
  brief_dir="$STATE/eindri-briefs"; mkdir -p "$brief_dir"
  brief_file="$brief_dir/$LABEL.md"; printf '%s\n' "$REQ" >"$brief_file"
  case "$KIND" in
    opencode) tmux_cmd="$("$SCRIPT_DIR/../seat/opencode-launcher.sh" print ${MODEL:+--model "$MODEL"} --brief "$brief_file")" || tmux_cmd="" ;;
    pi)       tmux_cmd="exec pi $(printf '%q' "$REQ")" ;;
    *)        tmux_cmd="exec $KIND" ;;
  esac
  if [ -z "$tmux_cmd" ]; then
    printf 'error: the %s launcher refused this seat — no tmux window was opened\n' "$KIND" >&2; exit 1
  fi
  tmux new-window -t "$SESSION" -n "$LABEL" -c "$PWD" bash -lc "$tmux_cmd" 2>/dev/null \
    && seat="tmux:$SESSION:$LABEL"
fi
[ "$refuse" = 1 ] && { printf 'eindri-start[1]{role,seat,verdict}:\n  "%s","none","too brief — answer it in hand"\n' "$ROLE"; exit 0; }
[ "$seat" != "none" ] || { printf 'error: could not seat %s\n' "$ROLE" >&2; exit 1; }

# 4. Serve the Eindri over A2A (best effort): its tasks are delivered by
#    injection into the seated agent's chat; reachable at A2A_URL.
A2A_URL=""
if [ "$seat" = herdr ] && [ -f "$SCRIPT_DIR/../bridge/a2a-serve.py" ]; then
  PORT=$((7800 + (RANDOM % 100)))
  mkdir -p "$STATE"
  nohup python3 "$SCRIPT_DIR/../bridge/a2a-serve.py" "$ROLE" "$ROLE" "$PORT" >"$STATE/a2a-$ROLE.log" 2>&1 &
  A2A_URL="http://127.0.0.1:$PORT/"
fi

# 5. Record + report.
printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROLE" "$seat" "$REQ" >>"$SEATS"
printf 'eindri-start[1]{role,seat,a2a,request,label}:\n'
printf '  "%s","%s","%s","%s","%s"\n' "$ROLE" "$seat" "${A2A_URL:-none}" "$REQ" "$LABEL"
# The model row is always printed: which model, and WHO decided — a seat that cannot
# say where its model came from cannot be trusted to have chosen it deliberately.
printf 'model[1]{agent,model,decided_by}:\n  "%s","%s","%s"\n' "$ROLE" "${MODEL:-default}" "${MODEL_NOTE:-$MODEL_SOURCE}"
