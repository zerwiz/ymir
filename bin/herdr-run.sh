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
# Hermes' skill is `ymir-thjazi`; the role chooser is `bin/eindri-role.sh`.
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

# The herdr CLI wrapper. Defaults to `hdr` (the Omarchy/Þjazi wrapper); a host
# may set HDR=herdr, or a future `hdr` that exposes `agent start`/`pane run`.
HDR="${HDR:-hdr}"
hdr() { "$HDR" "$@"; }

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${BROKK_STATE_OVERRIDE:-$ROOT/state}"
TAB_LOG="$STATE_DIR/herdr-seats"
SETTLE="${YMIR_HERDR_SETTLE:-300}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-available}"; shift || true

have() { command -v "$1" >/dev/null 2>&1; }

# herdr --session is the ONLY reliable router: HERDR_SESSION alone silently
# falls back to whichever server is already bound (firstmate docs/herdr-backend.md,
# "Session targeting"). We always pass the flag explicitly.
HDR_SESSION="${HERDR_SESSION:-default}"
hdr() { herdr "$@" --session "$HDR_SESSION"; }

can_use_herdr() {
  [ "${YMIR_HERDR_PANES:-1}" = "1" ] || return 1
  [ "${HERDR_ENV:-}" = "1" ] || return 1
  have herdr || return 1
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
seat_tab() {  # <name> <cwd> -> prints "<tab_id> <pane_id>"
  local name=$1 cwd=$2 ws out
  ws="$(home_workspace)"
  if [ -n "$ws" ]; then
    out="$(hdr tab create --workspace "$ws" --cwd "$cwd" --label "$name" 2>/dev/null)"
  else
    out="$(hdr tab create --cwd "$cwd" --label "$name" 2>/dev/null)"
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
  local name=$1 cwd=$2 out
  out="$(hdr workspace create --cwd "$cwd" --label "ymir:$name" 2>/dev/null)"
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
    hdr pane run "$pane" "$@" >/dev/null 2>&1; rc=$?
    hdr pane wait-output "$pane" --idle-ms 800 --timeout-secs "$SETTLE" >/dev/null 2>&1 || true
    printf 'herdr-run[1]{tab,pane,step,exit}:\n  "%s","%s","%s",%s\n' "$tab" "$pane" "$NAME" "$rc"
    exit "$rc" ;;
  agent|eindri)
    NAME=""; ROLE=""; SPACE=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --role) ROLE=${2-}; shift 2 ;;
        --role=*) ROLE=${1#--role=}; shift ;;
        --space) SPACE=1; shift ;;
        --) shift; break ;;
        -*) shift ;;
        *) if [ -z "$NAME" ]; then NAME="$1"; shift; else break; fi ;;
      esac
    done
    [ "${1:-}" = "--" ] && shift
    PROMPT="${*:-}"
    if ! can_use_herdr; then
      printf 'error: no herdr session — cannot seat an Eindri\nhelp: inside herdr, or use bin/einherjar-spawn.sh\n' >&2
      exit 1
    fi
    [ -n "$PROMPT" ] || { printf 'error: eindri needs a task after --\n' >&2; exit 2; }

    # The first law: short errands are done in hand.
    if ! worth_a_smith "$PROMPT" >/dev/null 2>&1; then
      printf 'herdr-run[1]{eindri,verdict}:\n  "none","short errand — answer it in hand"\n'
      exit 0
    fi

    # The right smith for the right metal.
    if [ -z "$ROLE" ] && [ -x "$SCRIPT_DIR/eindri-role.sh" ]; then
      ROLE="$("$SCRIPT_DIR/eindri-role.sh" choose "$PROMPT" 2>/dev/null | sed -n '2p' | sed -E 's/^ *"([^"]+)".*/\1/')"
    fi
    [ -n "$NAME" ] || NAME="${ROLE:-eindri}"
    KIND="${YMIR_HERDR_KIND:-pi}"

    # A space was asked for; if herdr is below the floor, fall back to a tab
    # rather than steal the active workspace on teardown.
    seat_note="tab"
    if [ "$SPACE" = 1 ]; then
      if space_supported; then
        read -r ws tab pane <<<"$(seat_space "$NAME" "$PWD")"
        [ -n "$ws" ] && seat_note="space $ws" && printf '%s\t%s\tspace:%s\n' "$tab" "$NAME" "$ws" >>"$TAB_LOG" 2>/dev/null || true
      else
        seat_note="tab (space floor not met)"
      fi
    fi
    if [ -z "${tab:-}" ]; then
      read -r tab pane <<<"$(seat_tab "$NAME" "$PWD")"
      [ -n "$tab" ] && printf '%s\t%s\n' "$tab" "$NAME" >>"$TAB_LOG" 2>/dev/null || true
    fi
    [ -n "$tab" ] || { printf 'error: could not seat the Eindri\n' >&2; exit 1; }
    [ -n "$pane" ] || { printf 'error: the tab has no pane\n' >&2; exit 1; }

    if ! hdr agent start "$NAME" --kind "$KIND" --pane "$pane" >/dev/null 2>&1; then
      printf 'error: could not start a %s Eindri in %s\nhelp: the pane must sit at an interactive shell prompt\n' "$KIND" "$pane" >&2
      exit 1
    fi
    hdr agent prompt "$NAME" "$PROMPT" >/dev/null 2>&1
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
