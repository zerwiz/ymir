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
#   eindri-start.sh "<request>" --id <task-id> [--project <path|id|alias>] [--role <name>] [--kind pi|opencode|claude]
#       # --id names a real errand and hands it to the engine
#       # (src/ymir_runtime/): a Yggdrasil worktree, a recorded seat, a
#       # heartbeat. Without --id the ordinary road below seats the agent.
#   eindri-start.sh "<request>" --project <path|id|alias> --dry-run
#       # print the seat plan — the project, its clone, the worktree, the branch,
#       # the pane's folder — and seat nothing.
#
# TWO BEARINGS EVERY ERRAND CARRIES (plan 291, 2026-11-14):
#   · a generated "Bearings" section is prepended to every brief, on both roads and for
#     every harness: the shipped fixed core + the home's overlay, the project's records
#     (resolved from the registry), and the home's document map (bin/agents/eindri-bearings.sh).
#   · --project takes a path, an id or an alias, resolved to THIS machine's clone through
#     hodd/identity/projects.yaml (bin/agents/project-target.sh). A worker for another
#     project is seated in THAT project's folder, in a worktree of THAT repository — never
#     in a worktree of Ymir's tree. A row with no clone on this machine is refused, named.
#   eindri-start.sh --version
set -u

# A CHILD DOES NOT INHERIT ITS PARENT'S PANE (2026-11-14, plan 275's stamp fault).
# A worker started from the helm's shell carried HERDR_PANE_ID=w39:pT, so every message
# it sent was stamped "agent Hœnir (the helm)" — the Allfather read it as the helm's own
# word. The pane IDENTITY is cleared here so no child can wear its parent's name; herdr
# sets the real one in the pane it seats, so nothing is lost by erasing it.
#
# What is deliberately NOT cleared: HERDR_ENV (the "inside herdr" capability flag
# herdr-run needs to seat at all), HERDR_SOCKET_PATH/HERDR_SESSION (the transport) and
# HERDR_WORKSPACE_ID (where the home's children belong). Clearing those unseats the
# worker — a fix that breaks the seat is a worse fault than the one it mends.
# bin/agents/msg-origin.sh also PROVES the pane against this process's ancestry, so this
# is the second ward: the stamp no longer trusts an inherited id even if one survives.
unset HERDR_PANE_ID HERDR_TAB_ID 2>/dev/null || true

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

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

REQ=""; ROLE=""; SEAT=""; MODEL=""; EFFORT=""; KIND="${YMIR_HERDR_KIND:-pi}"; MAIN=""; TASK_ID=""; PROJECT_DIR=""; PROJECT_EXPLICIT=""; DRY=0; KIND_EXPLICIT=""; MODEL_EXPLICIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE=${2-}; shift 2 ;;
    --kind) KIND=${2-}; KIND_EXPLICIT=$KIND; shift 2 ;;
    --model) MODEL=${2-}; MODEL_EXPLICIT=$MODEL; shift 2 ;;
    --effort) EFFORT=${2-}; shift 2 ;;
    --id) TASK_ID=${2-}; shift 2 ;;
    --project) PROJECT_DIR=${2-}; PROJECT_EXPLICIT=1; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --main) MAIN="--main"; shift ;;
    --space) SEAT="--space"; shift ;;
    --tab) SEAT="--tab"; shift ;;
    --pane) SEAT="--pane"; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/agents/eindri-start.sh "<request>" [--id <task-id>] [--role <name>] [--pane|--tab|--space] [--kind pi|opencode|claude] [--model M|free] [--effort low..max]\n' "$1" >&2; exit 2 ;;
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
# A Claude seat takes an Anthropic alias, never the role's provider/model token: the
# engine chooses it by the errand's weight (sonnet, or opus for --effort high|xhigh|max —
# the Allfather, 2026-11-12). Asking the role resolver here handed the engine a token it
# must refuse, and the Claude errand died before it was seated.
if [ "$KIND" = claude ] && [ -z "$MODEL" ]; then
  MODEL_SOURCE="errand weight (the engine picks sonnet or opus)"
elif [ -z "$MODEL" ] && [ -x "$SCRIPT_DIR/../model/agent-model.sh" ]; then
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

# 2c. WHERE THE ERRAND LIVES — the project, its clone, and the folder the worker sits in
#     (plan 291 part 3, at the Allfather's word: *"when we sending workers for diffrent projects
#     the need to be send from the project foldeers they are going to work in so they dont do the
#     updates in ymirs repo"*). A path, an id or an alias is resolved through the registry by ONE
#     door; nothing here guesses a convention. A project that is not this tree is seated in ITS OWN
#     repository, in a worktree made by that project's own convention — so an errand for another
#     project can never commit into Ymir's tree. A row with no clone here is refused, named.
PROJECT_TOKEN="${PROJECT_DIR:-$PWD}"
PROJECT_PATH=""; PROJECT_ID=""; PROJECT_KIND="unregistered"; PROJECT_HOW=""; PROJECT_RESOLVED=0
if [ -x "$SCRIPT_DIR/project-target.sh" ]; then
  resolved="$("$SCRIPT_DIR/project-target.sh" resolve "$PROJECT_TOKEN" 2>&1)"; rrc=$?
  if [ "$rrc" -eq 0 ]; then
    PROJECT_RESOLVED=1
    while IFS=$'\t' read -r _k _v; do
      case "$_k" in
        path) PROJECT_PATH="$_v" ;; id) PROJECT_ID="$_v" ;; kind) PROJECT_KIND="$_v" ;;
        how) PROJECT_HOW="$_v" ;;
      esac
    done <<<"$resolved"
  elif [ -n "$PROJECT_EXPLICIT" ]; then
    # an errand sent to a project this machine has no clone of is refused, with the row named
    printf '%s\n' "$resolved" >&2
    exit 1
  fi
  unset resolved rrc
fi
[ -n "$PROJECT_PATH" ] || PROJECT_PATH="$PWD"

# 2d. THE FOLDER THE WORKER SITS IN. In this tree the engine (or herdr-run) makes the worktree as it
#     always has; in another project's repository this door makes it, in that repository, and the
#     pane opens there. `--main` then tells herdr-run not to nest a second worktree inside it.
SEAT_MAIN="$MAIN"; WORKTREE=""; WORK_BRANCH=""; WORK_MADE=""
if [ "$PROJECT_KIND" = other ]; then
  WORK_ID="${TASK_ID:-$LABEL}"
  dry_flag=""; [ "$DRY" = 1 ] && dry_flag="--dry-run"
  plan="$("$SCRIPT_DIR/project-target.sh" worktree "$PROJECT_TOKEN" "$WORK_ID" $dry_flag 2>&1)" || {
    printf '%s\n' "$plan" >&2; exit 1; }
  while IFS=$'\t' read -r _k _v; do
    case "$_k" in worktree) WORKTREE="$_v" ;; branch) WORK_BRANCH="$_v" ;; created) WORK_MADE="$_v" ;; esac
  done <<<"$plan"
  unset plan dry_flag
  if [ "$DRY" = 0 ]; then
    [ -n "$WORKTREE" ] && [ -d "$WORKTREE" ] || {
      printf 'error: no worktree stands at %s — refusing to seat a worker in a main tree\nhelp: bin/agents/project-target.sh worktree %s %s\n' "${WORKTREE:-<none>}" "$PROJECT_TOKEN" "$WORK_ID" >&2
      exit 1; }
    cd "$WORKTREE" || { printf 'error: cannot enter %s\n' "$WORKTREE" >&2; exit 1; }
    SEAT_MAIN="--main"
  fi
fi

# 2e. THE BEARINGS every brief carries (plan 291 part 2): the shipped fixed core and the home's
#     overlay, the project's records, and the home's document map. Prepended, so it is read before
#     the errand; skipped when the brief already carries it, so a brief is never doubled.
if [ -x "$SCRIPT_DIR/eindri-bearings.sh" ]; then
  marker="$("$SCRIPT_DIR/eindri-bearings.sh" --marker 2>/dev/null || true)"
  case "$REQ" in
    *"${marker:-no-bearings-marker}"*) ;;
    *)
      bearings="$("$SCRIPT_DIR/eindri-bearings.sh" "$PROJECT_PATH" 2>/dev/null || true)"
      if [ -n "$bearings" ]; then
        REQ="$bearings

---

$REQ"
      else
        printf 'eindri-start: the bearings could not be read from %s — the brief goes out without its core\n' "$SCRIPT_DIR/eindri-bearings.sh" >&2
      fi ;;
  esac
  unset marker bearings
fi

# 2f. --dry-run: the seat PLAN and nothing else — no worktree, no pane, no process.
if [ "$DRY" = 1 ]; then
  printf 'eindri-start[1]{role,project,kind,project_path,worktree,branch,worktree_made,seat_cwd,harness,model,road,state}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","dry-run"\n' \
    "$ROLE" "${PROJECT_ID:-unregistered}" "$PROJECT_KIND" "$PROJECT_PATH" "${WORKTREE:-}" \
    "${WORK_BRANCH:-}" "${WORK_MADE:-}" "${WORKTREE:-$PWD}" "$KIND" "${MODEL:-default}" \
    "$([ "$PROJECT_KIND" = other ] && echo "a worktree in the project's own repository" || echo "this tree's own road")"
  printf 'bearings[1]{marker,core_carried}:\n  "%s","%s"\n' \
    "$("$SCRIPT_DIR/eindri-bearings.sh" --marker 2>/dev/null || echo none)" \
    "$(case "$REQ" in *eindri-bearings*) echo yes;; *) echo no;; esac)"
  exit 0
fi

# 3. The engine owns the errand when the caller names one (plan 58, Phase 1).
#    With --id an errand is a real seat — worktree, harness, record, heartbeat.
#    A seat hint (--pane/--tab/--space/--main) is the old road's grain, so those
#    callers keep the road below; YMIR_ENGINE=off skips the handoff entirely.
if [ -n "$TASK_ID" ] && [ -z "$SEAT" ] && [ -z "$MAIN" ] \
   && [ "${YMIR_ENGINE:-auto}" != "off" ] && [ -x "$SCRIPT_DIR/../engine/ymir-engine.sh" ] \
   && { [ "$PROJECT_RESOLVED" = 0 ] || [ "$PROJECT_KIND" = ymir ]; }; then
  PROJECT_DIR="$PROJECT_PATH"
  engine_args=(seat "$TASK_ID" --project "$PROJECT_DIR" --harness "$KIND" --request "$REQ" --role "$ROLE")
  if [ -n "$MODEL" ]; then engine_args+=(--model "$MODEL"); fi
  if [ -n "$EFFORT" ]; then engine_args+=(--effort "$EFFORT"); fi
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
  "$SCRIPT_DIR/../seat/herdr-run.sh" eindri $SEAT $SEAT_MAIN ${KIND_EXPLICIT:+--kind "$KIND_EXPLICIT"} ${MODEL:+--model "$MODEL"} "$ROLE" -- "$REQ" >/dev/null 2>&1 || rc=$?
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
