#!/usr/bin/env bash
# herdr-run.sh — raise an Eindri in herdr, by the grain that fits the errand.
#
# An Eindri is a delegated hand (AGENTS.md; docs/lore.md §II). Two roads seat one,
# and each fits its own country:
#
#   TAB      one tab in this home's workspace. Durable, ordinary, the default.
#            Use when the work will outlast the moment — a task with a worktree.
#   SPACE    a disposable workspace holding exactly this one errand, torn down
#            when it is done. Use when the work should leave no trace in the
#            workspace you are living in. Needs herdr 0.8.0+ (the projection
#            floor: below it, projected cleanup can steal the active workspace).
#
# And the first law, before either: a SHORT ERRAND IS DONE IN HAND. A question, a
# one-line check, a lookup — those are answered directly. Only a TASK earns a
# smith, because a smith costs a context, a seat, and your attention.
#
# Hermes' skill is the `ymir` thjazi asset; the role chooser is `bin/eindri-role.sh`.
#
# Usage:
#   bin/herdr-run.sh available                      # can we use herdr right now?
#   bin/herdr-run.sh worth-a-smith "<errand>"       # is this an errand at all?
#   bin/herdr-run.sh eindri [NAME] [--role R] [--space] -- "<task>"
#   bin/herdr-run.sh run <name> -- <command...>     # a command in a pane
#   bin/herdr-run.sh agent-status                   # who stands, and in what state
#   bin/herdr-run.sh close-all                      # clear the tabs/panes we made
#   bin/herdr-run.sh --version
#
# Env:
#   YMIR_HERDR_PANES=0      force inline even inside herdr
#   YMIR_HERDR_KIND=pi      the agent kind raised for `eindri`
#   YMIR_HERDR_AGENT_WAIT=1 wait for the Eindri to reach done before returning
#   YMIR_HERDR_SETTLE=300   seconds to wait for a step before declaring it hung
set -u


VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
STATE_DIR="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
TAB_LOG="$STATE_DIR/herdr-seats"
SETTLE="${YMIR_HERDR_SETTLE:-300}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-available}"; shift || true

have() { command -v "$1" >/dev/null 2>&1; }

# herdr --session is the ONLY reliable router: HERDR_SESSION alone silently
# falls back to whichever server is already bound (Brokk .agents/skills/herdr-panes/assets/herdr-backend.md,
# "Session targeting"). We always pass the flag explicitly.
HDR_SESSION="${HERDR_SESSION:-}"
# One backend, two names: upstream ships `herdr`, the Omarchy/Þjazi layer calls
# the same binary `hdr`. Resolve once so both hosts share this code path.
HDR_BIN="${HDR:-$(command -v herdr || command -v hdr || printf 'herdr')}"
hdr() { if [ -n "$HDR_SESSION" ]; then "$HDR_BIN" --session "$HDR_SESSION" "$@"; else "$HDR_BIN" "$@"; fi; }

can_use_herdr() {
  [ "${YMIR_HERDR_PANES:-1}" = "1" ] || return 1
  [ "${HERDR_ENV:-}" = "1" ] || return 1
  have herdr || have hdr || return 1
  return 0
}

current_pane() {
  printf '%s' "${HERDR_PANE_ID:-}"
}

# Which workspace this home's children belong in. One workspace per env home;
# the pane we sit in names it, else the injected workspace id.
home_workspace() {
  [ -n "${HERDR_WORKSPACE_ID:-}" ] && { printf '%s' "$HERDR_WORKSPACE_ID"; return 0; }
  hdr pane current 2>/dev/null | python3 -c '
import json,sys
try:
    d = json.load(sys.stdin); p = d.get("result", {}).get("pane", {})
    print(p.get("workspace_id") or "")
except Exception:
    pass' 2>/dev/null
}

# The projection floor: a disposable workspace per errand needs herdr 0.8.0+,
# below which a workspace-emptying close can steal the active workspace.
space_supported() {
  local protocol version
  protocol="$(hdr status --json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); print((d.get("client") or {}).get("protocol") or "")
except Exception:
    pass' 2>/dev/null)"
  version="$(hdr status --json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); print((d.get("client") or {}).get("version") or "")
except Exception:
    pass' 2>/dev/null)"
  # protocol 19 is the structural signal for the 0.8.0 floor (0.8.0 reports 19).
  case "$protocol" in ''|*[!0-9]*) ;; *) [ "$protocol" -ge 19 ] && return 0 ;; esac
  case "$version" in
    0.8.*|0.9.*|1.*|[1-9].*) return 0 ;;
  esac
  return 1
}

# The first law: is this worth a smith at all? A question, a lookup, a one-line
# check is done in hand. A task — work with an artifact, a worktree, a life
# beyond the answer — earns a seat.
worth_a_smith() {
  local text; text="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [ -n "$text" ] || { printf 'worth[1]{verdict,why}:\n  "no","empty"\n'; return 1; }
  local words; words="$(printf '%s' "$text" | wc -w | tr -d ' ')"
  # Interrogative and lookup shapes are answered in hand.
  case "$text" in
    *\?*|what\ *|why\ *|when\ *|where\ *|who\ *|how\ many*|how\ much*|show\ me*|tell\ me*|explain\ *|whats\ *|what\'s\ *)
      printf 'worth[1]{verdict,why}:\n  "no","a question — answer it in hand"\n'; return 1 ;;
  esac
  # A task names an artifact or an act of making.
  case "$text" in
    *build*|*fix*|*implement*|*refactor*|*write*|*create*|*add*|*migrate*|*port*|*test*|*review*|*research*|*audit*|*plan*|*design*|*document*|*investigate*|*compare*|*draft*|*forge*|*set\ up*|*install*)
      if [ "$words" -ge 4 ]; then
        printf 'worth[1]{verdict,why,words}:\n  "yes","a task with an artifact",%s\n' "$words"; return 0
      fi
      printf 'worth[1]{verdict,why,words}:\n  "no","too brief to seat a smith",%s\n' "$words"; return 1 ;;
  esac
  if [ "$words" -ge 24 ]; then
    printf 'worth[1]{verdict,why,words}:\n  "yes","substantial errand",%s\n' "$words"; return 0
  fi
  printf 'worth[1]{verdict,why,words}:\n  "no","short errand — do it in hand",%s\n' "$words"; return 1
}

# Seat an Eindri in a TAB of this home's workspace (the durable road).
# The reply carries result.tab.tab_id and result.root_pane.pane_id.
# A worker must never contend for the primary's helm, and must never write the
# primary's lock POINTER either. Both are keyed off the state dir, so the seat
# gets its own: BROKK_MACHINE_STATE_DIR resolves its lock
# (bin/gleipnir-lock-lib.sh), and BROKK_STATE_OVERRIDE resolves the state the
# pi extension reads the `.lock-path` pointer from. Setting only the former left
# the pointer shared: a seat wrote its own pointer over the primary's, the
# primary's extension read the seat's lock, called itself read-only, and
# supervision died (watcher: FAILED ... no longer owns the lock, 2026-09-23).
seat_state_dir() {  # <name> -> the seat's private state dir
  local name=${1:-eindri}
  printf '%s/ymir/seats/%s' "${XDG_STATE_HOME:-$HOME/.local/state}" "$name"
}
seat_state_env() {  # <name> -> KEY=VALUE for the machine lock (kept for callers)
  printf 'BROKK_MACHINE_STATE_DIR=%s' "$(seat_state_dir "${1:-eindri}")"
}

# Resolve a role to its figure file. The chooser (bin/eindri-role.sh) and
# config/agents.yaml speak SHORT roles (kvasir, sindri, bragi); the roster files
# carry the craft in the name (kvasir-scout.md, sindri-developer.md,
# bragi-marketer.md). Exact match first, then the short-role prefix.
role_file_for() {  # <role> -> path on stdout, non-zero when none
  local role=${1:-} f
  [ -n "$role" ] || return 1
  f="$ROOT/.agents/agents/$role.md"
  [ -r "$f" ] && { printf '%s' "$f"; return 0; }
  for f in "$ROOT/.agents/agents/$role"*.md; do
    [ -r "$f" ] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# Refuse a seat that would resolve the primary's helm. seat_state_env always
# lands under seats/<name>, so this is an assertion against future regressions,
# not a live collision — a silent collision is what let the watcher die.
seat_guard() {  # <name>; non-zero if the seat would share the primary's lock
  local name=${1:-eindri} seat_dir primary_dir
  seat_dir="$(seat_state_dir "$name")"
  primary_dir="${BROKK_MACHINE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
  [ "$seat_dir" != "$primary_dir" ]
}

seat_tab() {  # <name> <cwd> -> prints "<tab_id> <pane_id>"
  local name=$1 cwd=$2 ws out env_arg
  env_arg="$(seat_state_dir "$name")"
  ws="$(home_workspace)"
  if [ -n "$ws" ]; then
    out="$(hdr tab create --workspace "$ws" --cwd "$cwd" --label "$name" \
      --env "BROKK_MACHINE_STATE_DIR=$env_arg" --env "BROKK_STATE_OVERRIDE=$env_arg" 2>/dev/null)"
  else
    out="$(hdr tab create --cwd "$cwd" --label "$name" \
      --env "BROKK_MACHINE_STATE_DIR=$env_arg" --env "BROKK_STATE_OVERRIDE=$env_arg" 2>/dev/null)"
  fi
  printf '%s' "$out" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); r=d.get("result", {})
    tab=(r.get("tab") or {}).get("tab_id") or ""
    pane=(r.get("root_pane") or {}).get("pane_id") or ""
    print(tab, pane)
except Exception:
    pass' 2>/dev/null
}

# Seat an Eindri in a DISPOSABLE workspace (the projection road). One errand,
# one space, torn down when the errand ends.
seat_space() {  # <name> <cwd> -> prints "<workspace_id> <tab_id> <pane_id>"
  local name=$1 cwd=$2 out d
  d="$(seat_state_dir "$name")"
  out="$(hdr workspace create --cwd "$cwd" --label "ymir:$name" \
    --env "BROKK_MACHINE_STATE_DIR=$d" --env "BROKK_STATE_OVERRIDE=$d" 2>/dev/null)"
  printf '%s' "$out" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); r=d.get("result", {})
    w=r.get("workspace", r)
    ws=w.get("workspace_id") or w.get("id") or ""
    tab=(r.get("tab") or {}).get("tab_id") or ""
    pane=(r.get("root_pane") or {}).get("pane_id") or ""
    print(ws, tab, pane)
except Exception:
    pass' 2>/dev/null
}

first_pane_of_tab() {  # <tab-id> -> pane id
  hdr tab get "$1" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); r=d.get("result",{}); t=r.get("tab", r)
    panes=t.get("panes") or []
    print(panes[0].get("pane_id") if panes else (t.get("pane_id") or ""))
except Exception:
    pass' 2>/dev/null
}

# A pane to split when we are NOT sitting inside herdr: the active pane of this
# home's workspace. Inside herdr, the current pane is used directly.
home_pane() {
  local ws at
  ws="$(home_workspace)"; [ -n "$ws" ] || return 1
  at="$(hdr workspace list 2>/dev/null | python3 -c '
import json,sys
ws=sys.argv[1]
try:
    d=json.load(sys.stdin); wss=(d.get("result",{}) or {}).get("workspaces",[])
    for w in wss:
        if w.get("workspace_id")==ws:
            print(w.get("active_tab_id") or ""); break
except Exception:
    pass' "$ws" 2>/dev/null)"
  [ -n "$at" ] || return 1
  first_pane_of_tab "$at"
}

# Seat an Eindri in a PANE SPLIT — the companion road, so an Eindri sits beside
# the work rather than hidden in a tab. Splits the current pane (inside herdr)
# or this home's active pane. Prints "<tab_id> <pane_id>".
seat_pane() {  # <name> <cwd>
  local cwd=$2 target out d
  d="$(seat_state_dir "$1")"
  target="$(current_pane)"; [ -n "$target" ] || target="$(home_pane)"
  [ -n "$target" ] || return 1
  out="$(hdr pane split "$target" --direction right --cwd "$cwd" \
    --env "BROKK_MACHINE_STATE_DIR=$d" --env "BROKK_STATE_OVERRIDE=$d" 2>/dev/null)"
  printf '%s' "$out" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); p=(d.get("result",{}) or {}).get("pane",{})
    print(p.get("tab_id") or "", p.get("pane_id") or "")
except Exception:
    pass' 2>/dev/null
}

case "$ACTION" in
  available)
    if can_use_herdr; then
      printf 'herdr-run[1]{herdr,session,workspace,space_ok}:\n  "yes","%s","%s","%s"\n' \
        "$HDR_SESSION" "$(home_workspace)" "$(space_supported && echo yes || echo no)"
    else
      reason=""
      [ "${HERDR_ENV:-}" != "1" ] && reason="not inside herdr (HERDR_ENV unset)"
      [ "${YMIR_HERDR_PANES:-1}" != "1" ] && reason="YMIR_HERDR_PANES=0"
      have herdr || reason="herdr binary absent"
      printf 'herdr-run[1]{herdr,reason}:\n  "no","%s"\n' "${reason:-unknown}"
    fi
    exit 0 ;;
  worth-a-smith)
    worth_a_smith "${*:-}"; exit $? ;;
  run)
    NAME="${1:-step}"; shift || true
    [ "${1:-}" = "--" ] && shift
    [ $# -gt 0 ] || { printf 'error: run needs a command after --\n' >&2; exit 2; }
    if ! can_use_herdr; then "$@"; exit $?; fi
    mkdir -p "$STATE_DIR"
    read -r tab pane <<<"$(seat_tab "ymir:$NAME" "$PWD")"
    if [ -z "$pane" ]; then "$@"; exit $?; fi
    printf '%s\t%s\n' "$tab" "$NAME" >>"$TAB_LOG" 2>/dev/null || true
    # A pane runs its command through a shell, so every argument must be quoted
    # on the way in. Unquoted, a multi-word argument (`--brief "the whole task"`)
    # arrives as separate words and the command dies on its own second word.
    cmd=""
    for a in "$@"; do cmd="$cmd$(printf '%q ' "$a")"; done
    hdr pane run "$pane" "$cmd" >/dev/null 2>&1; rc=$?
    hdr pane wait-output "$pane" --idle-ms 800 --timeout-secs "$SETTLE" >/dev/null 2>&1 || true
    printf 'herdr-run[1]{tab,pane,step,exit}:\n  "%s","%s","%s",%s\n' "$tab" "$pane" "$NAME" "$rc"
    exit "$rc" ;;
  agent|eindri)
    NAME=""; ROLE=""; SPACE=0; TAB=0; MODEL_REQ=""; MAIN=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --role) ROLE=${2-}; shift 2 ;;
        --role=*) ROLE=${1#--role=}; shift ;;
        --model) MODEL_REQ=${2-}; shift 2 ;;
        --model=*) MODEL_REQ=${1#--model=}; shift ;;
        --space) SPACE=1; shift ;;
        --tab) TAB=1; shift ;;
        --pane) SPACE=0; TAB=0; shift ;;
        --main) MAIN=1; shift ;;
        --) shift; break ;;
        -*) shift ;;
        *) if [ -z "$NAME" ]; then NAME="$1"; shift; else break; fi ;;
      esac
    done
    [ "${1:-}" = "--" ] && shift
    PROMPT="${*:-}"

    # The seat brief (plan 46). A worker owns decisions inside its craft and has
    # NO human at its terminal: the ask-user questionnaire reaches whoever sits
    # at the pane, and a worker that asks it hands the Allfather a question the
    # worker should have decided. Say so up front, and name where a genuine
    # question goes — the coordinator's report file.
    PROMPT="$PROMPT

---
Seat law, read first. You are a worker figure, not the primary. There is NO human at this terminal: do NOT use ask_user_question — no questionnaire from this pane reaches the Allfather. Decide everything inside your craft yourself; that is why you were seated. If a genuine fork needs the coordinator, write the QUESTION to state/eindri-questions/$NAME.md and stop — Brokk is woken, answers it with bin/eindri-send.sh, and you carry on. When the errand is DONE, write the report to state/eindri-reports/$NAME.md. And if the same action fails twice, do not run it a third time: change the approach, or write down what blocked you. Repeating a command that returns nothing is a loop, not work."
    if ! can_use_herdr; then
      printf 'error: no herdr session — cannot seat an Eindri\nhelp: inside herdr, or use bin/einherjar-spawn.sh\n' >&2
      exit 1
    fi
    [ -n "$PROMPT" ] || { printf 'error: eindri needs a task after --\n' >&2; exit 2; }

    # The first law: short errands are done in hand.
    if ! worth_a_smith "$PROMPT" >/dev/null 2>&1; then
      printf 'herdr-run[1]{eindri,verdict}:\n  "none","short errand — answer it in hand"\n'
      exit 3
    fi

    # The right smith for the right metal.
    if [ -z "$ROLE" ] && [ -x "$SCRIPT_DIR/eindri-role.sh" ]; then
      ROLE="$("$SCRIPT_DIR/eindri-role.sh" choose "$PROMPT" 2>/dev/null | sed -n '2p' | sed -E 's/^ *"([^"]+)".*/\1/')"
    fi
    [ -n "$NAME" ] || NAME="${ROLE:-eindri}"
    KIND="${YMIR_HERDR_KIND:-pi}"

    # Resolve a model request (friendly or exact) to harness+provider+model.
    # local -> pi, online -> opencode. Unresolved -> report and continue default.
    MODEL_ARGS=()
    if [ -n "$MODEL_REQ" ] && [ -x "$SCRIPT_DIR/model-resolve.sh" ]; then
      r="$("$SCRIPT_DIR/model-resolve.sh" resolve "$MODEL_REQ" 2>/dev/null | sed -n '2p')"
      case "$r" in
        ""|*unresolved*)
          printf 'herdr-run[1]{model,state}:\n  "%s","unresolved — ask the Allfather"\n' "$MODEL_REQ" >&2 ;;
        *)
          loc="$(printf '%s' "$r" | cut -d'"' -f4)"
          h="$(printf '%s' "$r"   | cut -d'"' -f6)"
          pv="$(printf '%s' "$r"  | cut -d'"' -f8)"
          md="$(printf '%s' "$r"  | cut -d'"' -f10)"
          # The harness FOLLOWS the model: a local provider is pi's work, an
          # online one is opencode's. Trusting a field position here seated
          # pi with an online model id, so the worker started and sat IDLE -
          # "sent but never started" - while the dispatch row reported success.
          case "${md:-}:${pv:-}:${h:-}" in
            *llama*|*lmstudio*|*ollama*) KIND=pi ;;
            "")                          KIND=pi ;;   # nothing resolved: stay local
            *)                           KIND=opencode ;;
          esac
          [ -n "$md" ] && MODEL_ARGS=(-- --model "$pv/$md")
          printf 'herdr-run[1]{model,harness,provider,model_id}:\n  "%s","%s","%s","%s"\n' "$MODEL_REQ" "$h" "$pv" "$md" >&2 ;;
      esac
    fi

    # No explicit model: use the AGENT'S configured harness+model from
    # config/agents.yaml (local->pi, online->opencode) — never default silently.
    if [ -z "$MODEL_REQ" ] && [ -x "$SCRIPT_DIR/agents-config.sh" ]; then
      _h="$("$SCRIPT_DIR/agents-config.sh" get "$ROLE" harness 2>/dev/null)"
      _m="$("$SCRIPT_DIR/agents-config.sh" get "$ROLE" model 2>/dev/null)"
      [ -n "$_h" ] && KIND="$_h"
      [ -n "$_m" ] && MODEL_ARGS=(-- --model "$_m")
      printf 'herdr-run[1]{agent,harness,model}:\n  "%s","%s","%s"\n' "$ROLE" "${_h:-?}" "${_m:-?}" >&2
    fi

    # The figure's own file. Without it pi loads only AGENTS.md (which describes
    # Brokk) and EVERY seat believes it is Brokk — proven 2026-09-23: a seat
    # told nothing answered "I am Brokk, the Allfather's counsellor". pi reads
    # the role file through --append-system-prompt.
    if [ "$KIND" = "pi" ] && [ -n "$ROLE" ]; then
      role_file="$(role_file_for "$ROLE")" || role_file=""
      if [ -n "$role_file" ]; then
        [ ${#MODEL_ARGS[@]} -eq 0 ] && MODEL_ARGS=(--)
        MODEL_ARGS+=(--append-system-prompt "$role_file")
        printf 'herdr-run[1]{role,prompt}:\n  "%s","%s"\n' "$ROLE" "$role_file" >&2
      else
        printf 'herdr-run[1]{role,prompt,state}:\n  "%s","none","no role file — this seat may default to Brokk"\n' "$ROLE" >&2
      fi
    fi

    # Guard: the seat must not resolve the primary's helm.
    if ! seat_guard "$NAME"; then
      printf 'error: refusing to seat %s — it would share the primary session lock\nhelp: a worker gets its own BROKK_MACHINE_STATE_DIR (see seat_state_env)\n' "$NAME" >&2
      exit 1
    fi

    # Where the Eindri sits, in herdr's hierarchy (workspace > tab > pane):
    #   --space  a disposable workspace (one errand, torn down)
    #   --tab    a new tab in this home's workspace
    #   default  a PANE SPLIT beside the work (the companion road)
    # ISOLATION (law ygg1): never seat an Eindri in the main tree. Create or
    # reuse a Yggdrasil worktree and seat there.
    SEAT_CWD="$PWD"
    if [ "${MAIN:-0}" = 1 ]; then
      printf 'herdr-run[1]{isolation,worktree}:\n  "off (main tree — Allfather chose --main)"\n' >&2
    elif [ -x "$SCRIPT_DIR/yggdrasil.sh" ]; then
      # Reuse an existing worktree for this id; create only when absent.
      wt_path="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)/.yggdrasil/$NAME"
      if [ ! -d "$wt_path" ]; then
        wt_out="$("$SCRIPT_DIR/yggdrasil.sh" create "$NAME" 2>/dev/null)"
        wt_path="$(printf '%s' "$wt_out" | sed -n '2p' | cut -d'"' -f6)"
      fi
      if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
        SEAT_CWD="$(cd "$wt_path" && pwd)"
        printf 'herdr-run[1]{isolation,worktree}:\n  "on","%s"\n' "$SEAT_CWD" >&2
      else
        printf 'error: isolation — could not create a Yggdrasil worktree; refusing to seat in the main tree\nhelp: bin/yggdrasil.sh create %s\n' "$NAME" >&2
        exit 4
      fi
    fi

    seat_note="pane"
    if [ "$SPACE" = 1 ]; then
      if space_supported; then
        read -r ws tab pane <<<"$(seat_space "$NAME" "$SEAT_CWD")"
        [ -n "$ws" ] && seat_note="space $ws" && printf '%s\t%s\tspace:%s\n' "$tab" "$NAME" "$ws" >>"$TAB_LOG" 2>/dev/null || true
      else
        seat_note="tab (space floor not met)"
      fi
    elif [ "$TAB" = 1 ]; then
      seat_note="tab"
    else
      read -r tab pane <<<"$(seat_pane "$NAME" "$SEAT_CWD")"
      if [ -n "$tab" ]; then
        printf '%s\t%s\tpane\n' "$tab" "$NAME" >>"$TAB_LOG" 2>/dev/null || true
      else
        seat_note="tab (pane split unavailable)"
      fi
    fi
    if [ -z "${tab:-}" ]; then
      read -r tab pane <<<"$(seat_tab "$NAME" "$SEAT_CWD")"
      [ -n "$tab" ] && printf '%s\t%s\n' "$tab" "$NAME" >>"$TAB_LOG" 2>/dev/null || true
    fi
    [ -n "$tab" ] || { printf 'error: could not seat the Eindri\n' >&2; exit 1; }
    [ -n "$pane" ] || { printf 'error: the tab has no pane\n' >&2; exit 1; }

    if ! hdr agent start "$NAME" --kind "$KIND" --pane "$pane" "${MODEL_ARGS[@]}" >/dev/null 2>&1; then
      printf 'error: could not start a %s Eindri in %s\nhelp: the pane must sit at an interactive shell prompt\n' "$KIND" "$pane" >&2
      exit 1
    fi
    # Inject the task — retry until it lands. `agent start` can return before the
    # harness accepts input (opencode is slower than pi), and a single swallowed
    # prompt is the "it started but nothing was injected" bug.
    injected=no
    for _try in 1 2 3 4 5 6 7 8 9 10; do
      if hdr agent prompt "$NAME" "$PROMPT" >/dev/null 2>&1; then injected=yes; break; fi
      sleep 3
    done
    printf 'herdr-run[1]{eindri,injected,attempts}:\n  "%s","%s",%s\n' "$NAME" "$injected" "${_try:-0}" >&2

    # Arm the handoff (plan 42, the automation law). A when-source beside the
    # smith watches him and, the moment he reports (REPORT.md lands, or herdr
    # shows he left `working`), files the report, marks him done, and wakes
    # Brokk through state/.wake-queue. Without this a seated worker finishes
    # into silence and the coordinator has to poll by hand — the exact failure
    # plan 42 exists to kill.
    if [ -x "$SCRIPT_DIR/eindri-watch.sh" ]; then
      if "$SCRIPT_DIR/eindri-watch.sh" arm "$NAME" "$SEAT_CWD" >/dev/null 2>&1; then
        printf 'herdr-run[1]{eindri,armed}:\n  "%s","watch-%s"\n' "$NAME" "$NAME" >&2
      else
        printf 'herdr-run[1]{eindri,armed}:\n  "%s","failed — the handoff will not fire; wake Brokk by hand"\n' "$NAME" >&2
      fi
    fi

    if [ "${YMIR_HERDR_AGENT_WAIT:-1}" = "1" ]; then
      hdr agent wait "$NAME" --until done --until idle --timeout $((SETTLE * 1000)) >/dev/null 2>&1 || true
    fi
    printf 'herdr-run[1]{seat,eindri,role,kind,tab,state}:\n  "%s","%s","%s","%s","%s","%s"\n' \
      "$seat_note" "$NAME" "${ROLE:-unspecified}" "$KIND" "$tab" \
      "$(hdr agent get "$NAME" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); r=d.get("result",{}); a=r.get("agent",r)
    print(a.get("agent_status") or a.get("status") or "unknown")
except Exception:
    print("unknown")' 2>/dev/null)"
    ;;
  agent-status)
    if [ -x "$SCRIPT_DIR/herdr-agents.py" ]; then python3 "$SCRIPT_DIR/herdr-agents.py"
    else printf 'herdr-run[1]{state}:\n  "herdr-agents.py missing"\n'; fi
    ;;
  agent-stop)
    NAME="${1:-}"
    [ -n "$NAME" ] || { printf 'error: agent-stop needs a name\n' >&2; exit 2; }
    hdr agent stop "$NAME" >/dev/null 2>&1 || true
    printf 'herdr-run[1]{eindri,state}:\n  "%s","stopped"\n' "$NAME"
    ;;
  close-all)
    if [ -r "$TAB_LOG" ]; then
      while IFS=$'\t' read -r id name extra; do
        [ -n "$id" ] || continue
        case "$extra" in
          space:*) hdr workspace close "${extra#space:}" >/dev/null 2>&1 || hdr tab close "$id" >/dev/null 2>&1 || true ;;
          *)       hdr tab close "$id" >/dev/null 2>&1 || true ;;
        esac
      done <"$TAB_LOG"
      rm -f "$TAB_LOG"
    fi
    printf 'herdr-run[1]{state}:\n  "seats cleared"\n'
    ;;
  status)
    if [ -r "$TAB_LOG" ]; then
      printf 'herdr-run[%d]{seat,eindri}:\n' "$(grep -c . "$TAB_LOG" 2>/dev/null || echo 0)"
      while IFS=$'\t' read -r id name extra; do
        [ -n "$id" ] && printf '  "%s","%s"\n' "${extra:-$id}" "$name"
      done <"$TAB_LOG"
    else
      printf 'herdr-run[1]{state}:\n  "no seats recorded"\n'
    fi
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/herdr-run.sh [available|worth-a-smith|eindri|run|agent-status|close-all|status]\n' "$ACTION" >&2; exit 2 ;;
esac
