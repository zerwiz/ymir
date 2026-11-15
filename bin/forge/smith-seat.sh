#!/usr/bin/env bash
# smith-seat.sh — seat ANY figure in its own herdr workspace, the same way every time.
#
# WHY THIS EXISTS (the Allfather, 2026-11-07): *"why did you not spawn the repair smith and
# reviewer in the same [way]?"* — because there were two doors and only one worked. The reviewer
# was seated by `review-seat.sh`, which CREATES its own workspace and pane; the smith was seated by
# `herdr-run.sh eindri`, which needs an ALREADY-OPEN interactive shell pane — and on this seat that
# pane was never there, so every repair/conflict errand died with "the pane must sit at an
# interactive shell prompt" while the reviewer worked. A dispatch path that only works sometimes is
# worse than none: the loop looks alive and does nothing.
#
# This door does what the reviewer's seat does, for any figure:
#   create a workspace at the working directory → take its pane → `herdr agent start pi` with the
#   figure's role file and the errand brief → verify the agent actually reached a live state →
#   optionally hand it the prompt.
#
#   smith-seat.sh ensure --role sindri --brief <file> [--cwd <dir>] [--label <name>]
#   smith-seat.sh ask <name-or-pane> "<prompt>"      # hand the seated agent its errand
#   smith-seat.sh list                               # the seats this door made
#
# Exit: 0 seated/proven · 1 refused (and it says which step failed).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
_h=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root _h 2>/dev/null
# The ONE resolver says where the home is (Rule 07); a home it cannot name is a refusal, not a guess.
[ -n "$_h" ] || { printf 'smith-seat: the resolver (bin/vault/hoard-lib.sh) named no home\n' >&2; exit 1; }
STATE="$_h/state"

say()  { printf '%s\n' "$*"; }
die()  { printf 'smith-seat: %s\n' "$*" >&2; exit 1; }
refuse() { printf 'smith-seat: REFUSED — %s\n' "$*" >&2; exit 1; }

need_herdr() {
  command -v herdr >/dev/null 2>&1 || refuse "herdr is not on PATH — source ~/.config/ymir/seat-env.sh"
  herdr agent list >/dev/null 2>&1 || refuse "no herdr server answers — nothing can be seated"
}

jget() { python3 -c "import json,sys;d=json.load(sys.stdin);print($1)" 2>/dev/null || true; }

case "${1-}" in
  list)
    need_herdr
    herdr agent list 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("seats[3]{pane,name,state}:")
for a in d.get("result",{}).get("agents",[]):
    print(f"  \"{a.get(\"pane_id\")}\",\"{a.get(\"name\") or \"-\"}\",\"{a.get(\"agent_status\")}\"")'
    exit 0 ;;
  ask)
    need_herdr
    target="${2-}"; shift 2 || true
    text="${*:-}"
    [ -n "$target" ] || refuse "ask needs an agent name or pane id"
    [ -n "$text" ] || refuse "ask needs a prompt"
    herdr agent prompt "$target" "$text" >/dev/null 2>&1 && say "asked $target" || refuse "the agent at $target did not take the prompt"
    exit 0 ;;
  ensure) shift ;;
  ""|-h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) refuse "unknown action '${1-}': ensure | ask | list" ;;
esac

ROLE="sindri"; BRIEF=""; CWD="$ROOT"; LABEL="smith-seat"; PROMPT=""
while [ $# -gt 0 ]; do case "$1" in
  --role) ROLE="${2:-}"; shift 2 ;;
  --role=*) ROLE="${1#--role=}"; shift ;;
  --brief) BRIEF="${2:-}"; shift 2 ;;
  --brief=*) BRIEF="${1#--brief=}"; shift ;;
  --cwd) CWD="${2:-}"; shift 2 ;;
  --cwd=*) CWD="${1#--cwd=}"; shift ;;
  --label) LABEL="${2:-}"; shift 2 ;;
  --label=*) LABEL="${1#--label=}"; shift ;;
  --prompt) PROMPT="${2:-}"; shift 2 ;;
  --prompt=*) PROMPT="${1#--prompt=}"; shift ;;
  *) refuse "unknown argument $1" ;;
esac; done

need_herdr
[ -d "$CWD" ] || refuse "no working directory at $CWD"
ROLE_FILE="$ROOT/.agents/agents/$ROLE.md"
[ -r "$ROLE_FILE" ] || ROLE_FILE="$(ls "$ROOT"/.agents/agents/"$ROLE"-*.md 2>/dev/null | head -1)"
[ -r "${ROLE_FILE:-}" ] || refuse "no role file for '$ROLE' in $ROOT/.agents/agents/"
[ -n "$BRIEF" ] || refuse "--brief is required (the errand the figure is handed)"
[ -r "$BRIEF" ] || refuse "no brief at $BRIEF"

# A SEAT DOES NOT CARRY A SECOND TOOLKIT. Every ymir checkout — a worktree, a clone — ships its own
# `.pi/extensions`, and ~/.pi/agent/settings.json already names the primary's set, so pi loads both
# and every tool name collides ("Tool ymir_home conflicts with …", 40+ times) before a token is
# spent. Measured on this seat 2026-11-07, on the operator's own screen. The seat's copy is moved
# aside, not deleted: a worktree may still want to read it.
# MOVED OUT OF THE TREE, not beside it. A sibling `.pi/extensions.seat-hidden` is still INSIDE the
# worktree, so `git add -A` stages 55 deletions and a smith can ship them into the PR (caught on
# 2026-11-07, mid-errand). The seat's toolkit goes to the operator's state dir, where git cannot see it.
if [ -d "$CWD/.pi/extensions" ]; then
  stash_dir="$_h/state/.seat-extensions/$(basename "$CWD")"
  mkdir -p "$stash_dir" 2>/dev/null || true
  mv "$CWD/.pi/extensions" "$stash_dir/extensions" 2>/dev/null \
    && say "smith-seat: the seat's own extensions moved OUT of the tree ($stash_dir) — settings.json already loads the primary's"
fi

MODEL="$(bash "$ROOT/bin/model/agent-model.sh" "$ROLE" --plain 2>/dev/null || true)"
[ -n "$MODEL" ] || refuse "no model resolved for '$ROLE' — bin/model/agent-model.sh $ROLE --explain"

# THE SEATS HAVE A ROOM OF THEIR OWN, together — never split beside the primary, and never in a
# hidden workspace. "reviewer and repair smith in the same" (the Allfather): one workspace whose
# LABEL is the room, one TAB per seat inside it. He can see the room in the workspace list and does
# not have to share his own workspace with two agents.
WS_LABEL="${SEAT_WORKSPACE_LABEL:-review}"
ws="$(herdr workspace list 2>/dev/null | python3 -c '
import json,sys
want=sys.argv[1]
for w in json.load(sys.stdin).get("result",{}).get("workspaces",[]):
    if (w.get("label") or "")==want: print(w.get("workspace_id")); break
' "$WS_LABEL" 2>/dev/null || true)"
if [ -z "$ws" ]; then
  ws_out="$(herdr workspace create --cwd "$CWD" --label "$WS_LABEL" --no-focus 2>/dev/null)" \
    || refuse "herdr workspace create failed"
  ws="$(printf '%s' "$ws_out" | jget 'd.get("result",{}).get("workspace",{}).get("workspace_id","")')"
  [ -n "$ws" ] || refuse "herdr created no workspace (answer: $(printf '%s' "$ws_out" | head -c 160))"
  say "smith-seat: opened the '$WS_LABEL' room ($ws)"
fi
tab_out="$(herdr tab create --workspace "$ws" --cwd "$CWD" 2>/dev/null)" \
  || refuse "herdr tab create failed in workspace $ws"
pane="$(printf '%s' "$tab_out" | jget 'd.get("result",{}).get("root_pane",{}).get("pane_id","")')"
[ -n "$pane" ] || refuse "the new tab has no root pane (answer: $(printf '%s' "$tab_out" | head -c 160))"

# The agent NAME must be unique among live agents, or herdr refuses with `agent_name_taken` — which
# is exactly how the smith door failed while the reviewer worked: both asked for the name "pi".
# A name must be unique among LIVE agents, and a retired seat keeps its name until it exits — so a
# re-seat under the same label collided (`agent_name_taken`, measured twice). Each seating carries a
# short suffix; the label still says what the seat is for.
SEAT_NAME="$(printf '%s' "$LABEL" | tr -c 'a-z0-9_-' '-' | cut -c1-23)"; SEAT_NAME="${SEAT_NAME:-smith}"
SEAT_NAME="$SEAT_NAME-$(date +%H%M%S | cut -c3-6)"
herdr agent start "$SEAT_NAME" --kind pi --pane "$pane" -- --model "$MODEL" \
  --append-system-prompt "$ROLE_FILE" --append-system-prompt "$BRIEF" >/dev/null 2>&1 \
  || refuse "herdr agent start failed for pane $pane (model $MODEL)"

tries=0; st=""
while [ "$tries" -lt 20 ]; do
  st="$(herdr agent get "$pane" 2>/dev/null | jget 'd.get("result",{}).get("agent",{}).get("agent_status","")')"
  case "$st" in working|idle|done|blocked) break ;; esac
  tries=$((tries + 1)); sleep 0.5
done
case "$st" in working|idle|done|blocked) ;; *) refuse "the agent in $pane never reached a live state (last: ${st:-none})" ;; esac

# THE PROMPT MUST BE TAKEN, NOT TYPED INTO A BOOTING PANE. Measured 2026-11-07: the smith was
# seated and the prompt vanished — the agent was still starting, so the text went into a shell that
# was not yet pi's. Wait for `interactive_ready`, then hand it over and confirm the agent went to
# work; retry once, and refuse loudly if it never takes.
if [ -n "$PROMPT" ]; then
  ready=0
  for _i in $(seq 1 30); do
    line="$(herdr agent get "$pane" 2>/dev/null || true)"
    case "$line" in
      *'"interactive_ready":true'*) ready=1; break ;;
    esac
    sleep 1
  done
  [ "$ready" = 1 ] || printf 'smith-seat: %s never reported interactive_ready — handing the prompt anyway\n' "$pane" >&2
  taken=0
  for _try in 1 2 3; do
    herdr agent prompt "$pane" "$PROMPT" --wait --until working --timeout 60000 >/dev/null 2>&1 \
      && { taken=1; break; }
    herdr agent prompt "$pane" "$PROMPT" >/dev/null 2>&1 || true
    sleep 3
    st_now="$(herdr agent get "$pane" 2>/dev/null | jget 'd.get("result",{}).get("agent",{}).get("agent_status","")')"
    case "$st_now" in working|blocked|done) taken=1; break ;; esac
  done
  [ "$taken" = 1 ] || refuse "seated at $pane but the agent never took the prompt (state: ${st_now:-unknown})"
  printf 'smith-seat: the prompt was taken (state: %s)\n' "${st_now:-working}" >&2
fi
printf 'seat[5]{figure,workspace,pane,model,state}:\n  "%s","%s","%s","%s","%s"\n' \
  "$ROLE" "$ws" "$pane" "$MODEL" "$st"
