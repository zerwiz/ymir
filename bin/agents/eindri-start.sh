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

REQ=""; ROLE=""; ROLE_GIVEN=""; SEAT=""; MODEL=""; EFFORT=""; KIND="${YMIR_HERDR_KIND:-pi}"; MAIN=""; TASK_ID=""; PROJECT_DIR=""; PROJECT_EXPLICIT=""; DRY=0; KIND_EXPLICIT=""; MODEL_EXPLICIT=""; CLAIM_PR=""; CLAIM_PLAN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE=${2-}; ROLE_GIVEN=${2-}; shift 2 ;;
    --kind) KIND=${2-}; KIND_EXPLICIT=$KIND; shift 2 ;;
    --model) MODEL=${2-}; MODEL_EXPLICIT=$MODEL; shift 2 ;;
    --effort) EFFORT=${2-}; shift 2 ;;
    --id) TASK_ID=${2-}; shift 2 ;;
    --project) PROJECT_DIR=${2-}; PROJECT_EXPLICIT=1; shift 2 ;;
    --pr) CLAIM_PR=${2-}; shift 2 ;;
    --plan) CLAIM_PLAN=${2-}; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --main) MAIN="--main"; shift ;;
    --space) SEAT="--space"; shift ;;
    --tab) SEAT="--tab"; shift ;;
    --pane) SEAT="--pane"; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/agents/eindri-start.sh "<request>" [--id <task-id>] [--role <name>] [--pane|--tab|--space] [--kind pi|opencode|claude] [--model M|free] [--effort low..max] [--pr <url|owner/repo#n>] [--plan <n.step>]\n' "$1" >&2; exit 2 ;;
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
  # A --kind named here is the harness the model is judged against; with none, the role's own
  # row decides — and a row that runs on Claude (the judge: forseti { model: opus, harness: claude })
  # seats Claude with the name the CLI takes, never a pi model on a Claude seat (2026-11-21).
  resolved="$("$SCRIPT_DIR/../model/agent-model.sh" "$ROLE" --json ${KIND_EXPLICIT:+--harness "$KIND_EXPLICIT"} 2>/dev/null || true)"
  if [ -n "$resolved" ]; then
    MODEL="$(printf '%s' "$resolved" | sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    MODEL_SOURCE="$(printf '%s' "$resolved" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    row_harness="$(printf '%s' "$resolved" | sed -n 's/.*"harness"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    if [ -z "$KIND_EXPLICIT" ] && [ "$row_harness" = claude ]; then KIND=claude; KIND_EXPLICIT=claude; fi
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
# Plan 339.4: every worktree made below — by project-target.sh, herdr-run or the engine — is
# recorded in the reaper's ledger under THIS road and the errand's role as its owner.
export YMIR_WORKTREE_ROAD="${YMIR_WORKTREE_ROAD:-eindri-start}" YMIR_WORKTREE_OWNER="${YMIR_WORKTREE_OWNER:-$ROLE}"
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

# 2d'. THE WELL IS READ BEFORE WORK (plan 350 E): the top episodes for THIS task, asked of the raw task
#      text before the bearings are prepended, and appended after it as data. Never doubled; a well that
#      does not answer is said in the section, never a refusal to launch.
if [ -x "$SCRIPT_DIR/../records/well-brief.sh" ]; then
  _wm="$("$SCRIPT_DIR/../records/well-brief.sh" --marker 2>/dev/null || true)"
  case "$REQ" in
    *"${_wm:-no-well-marker}"*) ;;
    *) _well="$(timeout 20 "$SCRIPT_DIR/../records/well-brief.sh" "$REQ" 2>/dev/null || true)"
       [ -n "$_well" ] && REQ="$REQ

---

$_well" ;;
  esac
  unset _wm _well
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
  # The Claude permission profile this seat would carry: chosen by the GIVEN role only, never the guess.
  printf 'seat_profile[1]{role_given,role_guessed,profile}:\n  "%s","%s","%s"\n' \
    "${ROLE_GIVEN:-none}" "$([ -n "$ROLE_GIVEN" ] && echo none || echo "$ROLE")" \
    "$(basename "$("$SCRIPT_DIR/../seat/claude-seat.sh" profile "$ROLE_GIVEN" 2>/dev/null || echo unknown)")"
  printf 'bearings[1]{marker,core_carried}:\n  "%s","%s"\n' \
    "$("$SCRIPT_DIR/eindri-bearings.sh" --marker 2>/dev/null || echo none)" \
    "$(case "$REQ" in *eindri-bearings*) echo yes;; *) echo no;; esac)"
  exit 0
fi

# 2g. CLAIM BEFORE SEATING (plan 343.12). Every task is held by one seat at a time, and the claim is
#     a tracked file in the home, so every seat sees it (bin/agents/claim.sh). The keys are the task's
#     own names: --pr <url|owner/repo#n> → pr:…, --plan <n.step> → plan:…, and the errand's branch →
#     branch:<owner>/<repo>:<name> (what the push ward, claim-guard, reads). A task another seat holds
#     is refused here, naming the holder, before a worktree or a pane is made. A judge (forseti) holds
#     the PR as `judge`; everyone else as `coder`. A claim taken here is let go if the seat fails.
CLAIM_SH="$SCRIPT_DIR/claim.sh"; CLAIMED=()
CLAIM_ROLE=coder; [ "$ROLE" = forseti ] && CLAIM_ROLE=judge
CLAIM_ERRAND="${TASK_ID:-$LABEL}"
claims_unwind() { # release what this door took, unless the seat stood
  [ "${SEATED_OK:-0}" = 1 ] && return 0
  local k; for k in "${CLAIMED[@]:-}"; do [ -n "$k" ] && "$CLAIM_SH" release "$k" --role "$CLAIM_ROLE" >/dev/null 2>&1; done
}
claim_take() { # <key> — take it, or stop the errand with the holder's name
  local out rc=0
  out="$("$CLAIM_SH" take "$1" --role "$CLAIM_ROLE" --errand "$CLAIM_ERRAND" 2>&1)" || rc=$?
  if [ "$rc" = 0 ]; then CLAIMED+=("$1"); return 0; fi
  printf '%s\n' "$out" >&2
  if [ "$rc" = 1 ]; then printf 'error: %s is another seat'"'"'s task — no errand was seated\n' "$1" >&2; exit 1; fi
  printf 'eindri-start: the claims ledger could not be used (claim.sh exit %s) — seating without a claim\n' "$rc" >&2
}
if [ "$DRY" = 0 ] && [ -x "$CLAIM_SH" ] && [ "${YMIR_CLAIMS:-on}" != off ]; then
  trap claims_unwind EXIT
  slug_of() { git -C "${PROJECT_PATH:-$PWD}" remote get-url origin 2>/dev/null \
      | sed -nE 's#^(https://|git@|ssh://git@)?github\.com[:/]([^/]+/[^/.]+)(\.git)?/?$#\2#p'; }
  if [ -n "$CLAIM_PR" ]; then
    case "$CLAIM_PR" in
      http*://github.com/*/pull/*) _s="$(printf '%s' "$CLAIM_PR" | sed -nE 's#^https://github\.com/([^/]+/[^/]+)/pull/([0-9]+).*#\1#p')"; _n="$(printf '%s' "$CLAIM_PR" | sed -nE 's#.*/pull/([0-9]+).*#\1#p')" ;;
      */*#*) _s="${CLAIM_PR%%#*}"; _n="${CLAIM_PR##*#}" ;;
      *) _s="$(slug_of)"; _n="${CLAIM_PR#\#}" ;;
    esac
    [ -n "${_s:-}" ] && [ -n "${_n:-}" ] || { printf 'error: --pr wants a PR url or owner/repo#n (got %s)\n' "$CLAIM_PR" >&2; exit 2; }
    claim_take "pr:$_s#$_n"
    # the PR's head branch is the one a rework pushes to: claim it too, so the push ward sees it
    if [ "$CLAIM_ROLE" = coder ] && command -v gh >/dev/null 2>&1; then
      _hb="$(gh pr view "$_n" -R "$_s" --json headRefName -q .headRefName 2>/dev/null || true)"
      [ -n "$_hb" ] && claim_take "branch:$_s:$_hb"
    fi
  fi
  [ -n "$CLAIM_PLAN" ] && claim_take "plan:$CLAIM_PLAN"
  if [ "$CLAIM_ROLE" = coder ]; then
    _wb="${WORK_BRANCH:-${TASK_ID:+eindri/$TASK_ID}}"; _ws="$(slug_of)"
    [ -n "$_wb" ] && [ -n "$_ws" ] && claim_take "branch:$_ws:$_wb"
  fi
  unset _s _n _hb _wb _ws
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
    SEATED_OK=1
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

# 3. Seat: herdr whenever herdr is installed; tmux ONLY where it is not (plan 275 item 31, 2026-11-14).
#    rc 3 from herdr-run means "not worth a smith" — report it, do NOT fake a seat.
#    Measured 2026-11-14: nine workers fell silently into tmux because herdr-run was handed the ROLE as the seat
#    name (every sindri errand asked for the one worktree `.yggdrasil/sindri`, which a stale branch blocked) and any
#    herdr failure was read as "herdr is absent". Now the ERRAND names the seat, the role is passed as --role, the
#    herdr road's own error is shown, and a herdr failure on a machine that has herdr is an error, never a tmux seat.
seat="none"; refuse=0; rc=0
# herdr counts as present only when it is installed AND the operator has not turned its panes off
# (YMIR_HERDR_PANES=0 is herdr-run's own documented switch for "inline, no panes"): that choice is not a fault.
HERDR_INSTALLED=0; command -v herdr >/dev/null 2>&1 && [ "${YMIR_HERDR_PANES:-1}" = "1" ] && HERDR_INSTALLED=1
# A launch from a unit or a cron has no herdr in its environment: reach herdr by its socket, and never hand a child
# the launcher's own pane (the child gets its own; the [from …] stamp depends on it).
[ -n "${HERDR_SOCKET_PATH:-}" ] || { _hs="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/herdr.sock"; [ -S "$_hs" ] && export HERDR_SOCKET_PATH="$_hs"; }
unset HERDR_PANE_ID HERDR_TAB_ID
SEAT_NAME="${TASK_ID:-$LABEL}"
herdr_err="$STATE/eindri-briefs/$SEAT_NAME.herdr-seat.err"; mkdir -p "$STATE/eindri-briefs"
if [ -x "$SCRIPT_DIR/../seat/herdr-run.sh" ] && [ "$HERDR_INSTALLED" = 1 ]; then
  # The role reaches herdr-run as --role ONLY when the caller gave one (RULES/08, 2026-11-21, the
  # judge's re-review of #870). A role GUESSED above (eindri-role.sh choose: "review the pr",
  # "verify the release" -> forseti) travels as --role-guess: it picks the pi role file and the
  # seat's name, and never the Claude permission profile — a guess must not open the merge door.
  if [ -n "$ROLE_GIVEN" ]; then _role_arg=(--role "$ROLE"); else _role_arg=(--role-guess "$ROLE"); fi
  "$SCRIPT_DIR/../seat/herdr-run.sh" eindri $SEAT $SEAT_MAIN ${KIND_EXPLICIT:+--kind "$KIND_EXPLICIT"} ${MODEL:+--model "$MODEL"} "${_role_arg[@]}" "$SEAT_NAME" -- "$REQ" >"$herdr_err.out" 2>"$herdr_err" || rc=$?
fi
if [ "$HERDR_INSTALLED" = 1 ] && [ "$rc" != 0 ] && [ "$rc" != 3 ]; then
  printf 'eindri-start[1]{role,seat,errand}:\n  "%s","none","%s"\n' "$ROLE" "$SEAT_NAME"
  printf 'error: herdr is installed but could not seat %s (herdr-run exit %s) — refused rather than hiding it in tmux\n' "$SEAT_NAME" "$rc" >&2
  sed 's/^/  herdr-run: /' "$herdr_err" | tail -8 >&2
  exit 1
fi
if [ "$rc" = 0 ] && [ "$HERDR_INSTALLED" = 1 ]; then
  seat="herdr"
elif [ "$rc" = 3 ]; then
  seat="none"; refuse=1
else
  printf 'eindri-start: herdr is not installed on this machine — seating %s in tmux\n' "$SEAT_NAME" >&2
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
# The refusal names its real cause (a question, too short, a busy local model), as herdr-run said it.
if [ "$refuse" = 1 ]; then
  why=$(sed -n 's/^ *"none","\([^"]*\)".*/\1/p' "$herdr_err.out" 2>/dev/null | tail -n 1)
  printf 'eindri-start[1]{role,seat,verdict}:\n  "%s","none","%s"\n' "$ROLE" "${why:-herdr-run refused the seat (exit 3) and gave no reason}"
  exit 0
fi
[ "$seat" != "none" ] || { printf 'error: could not seat %s\n' "$ROLE" >&2; exit 1; }
SEATED_OK=1   # the seat stands: its claims stay held (claim.sh releases them when the errand closes or goes stale)

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
