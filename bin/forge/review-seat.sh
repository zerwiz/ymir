#!/usr/bin/env bash
# review-seat.sh — the reviewer's SEAT: pi in a herdr pane, on the heart, on a loop.
#
# WHY (the Allfather, 2026-11-06): *"make so were using the pi harness in herdr for this work."*
# Plan 203 §12 asked for a reviewer that lives on the heart, in a herdr pane, running pi, so it
# reviews while the fleet sleeps. The doors were built; the SEAT was not. This is the seat:
#
#   one workspace named `review`, one pi agent in it, its cwd a CLONE (never a worktree of a
#   smith's), its charter the judge's role file plus the law it judges by, and its model resolved
#   for THAT seat (bin/model/agent-model.sh — never a model id in this file).
#
# THE SEAT LAWS IT KEEPS (herdr-panes skill, 2026-09-23):
#   · a seat loads its own figure — `--append-system-prompt <role file>`, or pi believes it is Brokk;
#   · a seat never takes the helm — a private BROKK_MACHINE_STATE_DIR on the workspace, set at
#     CREATE time because `herdr agent start` has no --env.
#
# Usage:
#   review-seat.sh status                       # is the seat there, and what is it doing
#   review-seat.sh ensure [--clone <path>] [--primary]
#                                               # raise it (idempotent), re-raising it when the
#                                               # pane holds no agent; --primary takes the helm
#                                               # when no live primary holds the lock, and is a
#                                               # plain seat when one does
#   review-seat.sh ask <pr> [--wait]            # put one PR in front of the seated judge
#   review-seat.sh charter                      # print the charter it would load
#   review-seat.sh close                        # lower the seat's workspace
#   review-seat.sh --install-unit               # DURABLE + VISIBLE: a herdr server unit, and a
#                                               # keeper timer that re-raises the seat if it dies
#   review-seat.sh --unit-status | --uninstall-unit
#
# Exit: 0 ok · 1 a fault (named) · 2 usage · 3 refused (not inside herdr / no clone).
set -u
VERSION="1.0.0"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE=""; hoard_state_dir STATE 2>/dev/null || true
HOME_DIR=""; ymir_home_root HOME_DIR 2>/dev/null || true
[ -n "$STATE" ] || { printf 'review-seat: the state dir is unresolved\n' >&2; exit 1; }
[ -n "$HOME_DIR" ] || { printf 'review-seat: the home is unresolved (bin/vault/hoard-lib.sh)\n' >&2; exit 1; }

WORKSPACE_LABEL="review"
ROLE_FILE="$ROOT/.agents/agents/forseti-reviewer.md"
CHARTER="$STATE/review/charter.md"
DEFAULT_CLONE="${YMIR_REVIEW_CLONE:-$HOME/review/ymir}"

die()    { printf 'review-seat: %s\n' "$*" >&2; exit 1; }
usage()  { printf 'review-seat: %s\n' "$*" >&2; exit 2; }
refuse() { printf 'review-seat: REFUSED — %s\n' "$*" >&2; exit 3; }

# The honest probe is the SERVER answering, not a variable: a herdr CLI reaches its server from
# a pane, from a timer and over ssh, and refusing on HERDR_ENV alone would refuse every one of
# those while the server stands (RULES/25 — probe, never assume).
need_herdr() {
  command -v herdr >/dev/null 2>&1 \
    || refuse "herdr is not installed on this seat — the reviewer's seat lives in herdr"
  herdr agent list >/dev/null 2>&1 \
    || refuse "the herdr server does not answer here — start it (herdr) or run this on the machine that will review"
}

# ── the seat's PRESENCE: a pane is not an agent (plan 189 §18.2) ────────────────────────────────
# Measured on the heart, 2026-11-14: pi died at start in the seat, the pane fell back to a bare
# shell, and the keeper kept counting that pane as "the seat" — because a pane whose cwd is the
# review clone is where the seat would STAND, never the seat itself. So nothing re-raised it, and
# the review watch prompted a shell every ten minutes. Presence is therefore two questions: where
# the panes are, and whether an agent is still standing in each of them.
#
# Herdr's JSON is read by ONE door — bin/seat/herdr-agents.py, which answers the pane question
# beside the agent one — so this file keeps no second parser of herdr's shapes.

SEAT_READER="$ROOT/bin/seat/herdr-agents.py"
herdr_read() { python3 "$SEAT_READER" "$@" 2>/dev/null || true; }

# Every pane whose cwd is the review clone, agent or not. A PANE is the question here: an agent
# list cannot see a shell, and a shell is exactly what is left when pi dies at start.
seat_candidates() {  # <clone> -> pane ids, one per line
  local out
  out="$(herdr_read --panes --cwd "$1" | cut -f1)"
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0
}

# Is an agent STANDING in this pane, and is it alive? Three answers, and only one of them may close
# a pane: `live` (herdr reports an agent in a live state), `dead` (herdr says plainly that no agent
# is here), `unsure` (no readable answer — never a licence to close somebody's live seat).
pane_verdict() {  # <pane> -> live | dead | unsure
  local v
  v="$(herdr_read --verdict --pane "$1" | head -1 | cut -f1)"
  case "$v" in live|dead) printf '%s\n' "$v" ;; *) printf 'unsure\n' ;; esac
}

# Herdr's own word for the agent's state in one pane (empty when no agent stands there), read from
# the SAME call as the verdict so the keeper's report and its decision cannot disagree.
pane_state() {  # <pane>
  herdr_read --verdict --pane "$1" | head -1 | cut -f2
}

seat_panes() {  # <clone> <live|dead> -> this clone's panes in that state
  local clone=$1 want=${2:-live} p v
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    v="$(pane_verdict "$p")"
    [ "$v" = "$want" ] && printf '%s\n' "$p"
  done <<< "$(seat_candidates "$clone")"
  return 0
}

# The seat itself: a LIVE agent in a pane whose cwd is the review clone. A shell is not the seat.
seat_pane() {  # -> pane id (or empty)
  local clone=$1 p
  p="$(seat_panes "$clone" live | head -1)"
  [ -n "$p" ] && printf '%s\n' "$p"
  return 0
}

# The `review` room, resolved once so a pane can be judged the seat's own or somebody else's.
seat_room() {  # -> workspace id (or empty)
  herdr_read --room --label "$WORKSPACE_LABEL"
}

pane_room() {  # <pane> -> the workspace it stands in (or empty)
  herdr_read --pane-room --pane "$1"
}

# The first line of a failure, for the journal: an error's own words, never a wall of output.
first_error_line() {  # <text>
  local line
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | tr -d '\r' | sed 's/[[:space:]]*$//')"
    if [ -n "$line" ]; then printf '%s\n' "${line:0:300}"; return 0; fi
  done <<EOF
$1
EOF
  printf '(the failure said nothing)\n'
}

# pi died at start and the pane kept the reason: read it and report ITS line. The measured cause is
# two extension sets registering the same tool names (RULES/13), which herdr reports as "the pane
# must sit at an interactive shell prompt" — a line that names nothing to fix.
pane_error_line() {  # <pane>
  local text hit
  text="$(herdr pane read "$1" --lines 80 2>/dev/null || true)"
  if [ -z "$text" ]; then printf 'the pane is empty — it holds no reason\n'; return 0; fi
  hit="$(printf '%s\n' "$text" | grep -m1 -E 'conflicts with|Tool "|Cannot find module|rror:|FATAL|panic|Traceback|not found|No such file' || true)"
  [ -n "$hit" ] || hit="$(printf '%s\n' "$text" | grep -v '^[[:space:]]*$' | tail -1)"
  hit="$(printf '%s' "$hit" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$hit" ] || hit="the pane holds nothing readable"
  printf '%s\n' "${hit:0:300}"
}

write_charter() {
  local clone=$1
  mkdir -p "$STATE/review" || die "cannot create $STATE/review"
  {
    printf '# The reviewer charter — Forseti the Judge\n\n'
    printf 'You are the reviewer for %s. You judge; you do not author.\n\n' "$clone"
    printf '## The law you load, in this order\n\n'
    printf '1. %s/AGENTS.md — the repository contract\n' "$clone"
    printf '2. %s/RULES/ — the house law (04 · 06 · 07 · 08 · 25 · 43 · 44)\n' "$clone"
    printf '3. %s/.review-rules.yaml — this project'"'"'s own declarations (a missing one is a REFUSAL)\n' "$clone"
    printf '4. plan 203 §12 (the reviewer on the heart) and plan 206 (the loop, the mouth, the switch)\n'
    printf '\n## YOUR MOUTH — a verdict nobody receives is not a verdict (plan 206 §12)\n\n'
    printf 'You answer in a pane, and a pane is not a delivery. So every act that matters ends with ONE call:\n\n'
    printf '  bash %s/bin/notify/send.sh --source review --severity HIGH --message "<one line: PR #, verdict, why, what happens next>"\n' "$ROOT"
    printf '\nA PASS is INFO; a REFUSE is HIGH because it stops work. That call carves the Runes entry and puts the\n'
    printf 'line in the arm'"'"'s wake queue, so the next session sees it without opening your pane. If it fails, say so\n'
    printf 'out loud in one line — never finish silently.\n\n'
    printf '## TALKING TO THE OTHER HANDS\n\n'
    printf 'They are in the same herdr workspace as you, one tab each. To hand work back or ask a peer:\n\n'
    printf '  herdr agent list                      # who is standing, and their names\n'
    printf '  herdr agent prompt <name> "<one line>"  # speak into that seat\n\n'
    printf 'The smith you need is named for its errand (`repair-smith-<pr>`, `conflict-smith-<pr>`). Name it and ask.\n'
    printf '\n## WHAT A VERDICT MUST CONTAIN (the Allfather: "your not delivering enough info")\n\n'
    printf 'A verdict that says "ready" is a mouth that says nothing. The report file must carry four fields:\n\n'
    printf '  What was judged: PR #, branch, head sha\n'
    printf '  What I ran: the floor (ruleset/seat/at), the wards (tally), the tests (command and tail)\n'
    printf '  Verdict: PASS | REFUSE | NEEDS-REWORK — and the ONE reason, quoting rule/file/line on a refusal\n'
    printf '  Next: who must act, and on what\n\n'
    printf 'Write it with `bin/forge/review-verdict.sh write <pr> --head <sha> --verdict … --reason … --finding …`\n'
    printf 'so the loop delivers it; the file alone is also delivered by bin/forge/verdict-watch.sh.\n'


    LEDGER=""; ymir_plan_dir LEDGER 2>/dev/null || true
    printf '   in %s\n\n' "${LEDGER:-the plan ledger under $HOME_DIR}"
    printf '## What you may do\n\n'
    printf -- '- read everything; run the gates and the tests YOURSELF on the fetched head\n'
    printf -- '- mark every claim in a packet verified or unverified\n'
    printf -- '- write ONE verdict to %s/eindri-reports/pr-<n>-review.md, first line PASS or REFUSE\n' "$STATE"
    printf -- '- ask the lock owner anything you may not do: bash bin/seat/lock-ask.sh ask "<question>"\n\n'
    printf '## What you may never do\n\n'
    printf -- '- merge, push, force-push, delete a branch, or edit the work you judge\n'
    printf -- '- review your own authored work; review a head that moved after the packet\n'
    printf -- '- pass a change on a red gate, an unverified claim, or a missing rules floor\n'
  } >"$CHARTER" || die "cannot write the charter at $CHARTER"
  printf '%s' "$CHARTER"
}

cmd_charter() {
  local clone=${1:-$DEFAULT_CLONE}
  local f; f="$(write_charter "$clone")"
  cat "$f"
}

cmd_status() {
  local clone=${1:-$DEFAULT_CLONE}
  need_herdr
  local pane; pane="$(seat_pane "$clone")"
  if [ -z "$pane" ]; then
    # a pane at the clone with NO agent is not the seat — name it, rather than calling a shell a seat
    local dead; dead="$(seat_panes "$clone" dead | head -1)"
    if [ -n "$dead" ]; then
      printf 'seat[3]{clone,pane,state}:\n  "%s","%s","not the seat — that pane holds no agent; ensure closes it and raises a fresh one"\n' "$clone" "$dead"
    else
      printf 'seat[3]{clone,pane,state}:\n  "%s","none","not seated — review-seat.sh ensure"\n' "$clone"
    fi
    return 0
  fi
  printf 'seat[3]{clone,pane,state}:\n  "%s","%s","%s"\n' "$clone" "$pane" "$(pane_state "$pane")"
}

cmd_ensure() {
  local clone=$DEFAULT_CLONE PRIMARY=0
  while [ $# -gt 0 ]; do case "$1" in
    --clone) clone="${2:-}"; shift 2 ;;
    --clone=*) clone="${1#--clone=}"; shift ;;
    --primary) PRIMARY=1; shift ;;
    *) shift ;;
  esac; done
  need_herdr
  # the pin is what every app and service runs: a judge never sits in it (plan 275, 2026-11-12)
  local _pin_real; _pin_real="$(readlink -f "${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}" 2>/dev/null)"
  if [ -n "$_pin_real" ] && [ "$(readlink -f "$clone" 2>/dev/null)" = "$_pin_real" ]; then
    printf 'review-seat: %s is the pinned runtime — the judge uses its own clone (%s) instead\n' "$clone" "$HOME/review/ymir" >&2
    clone="$HOME/review/ymir"
  fi
  # the judge's clone is made when it is missing, from the same remote the pin follows — the feature works on a new seat
  if [ ! -d "$clone/.git" ]; then
    local _url; _url="$(git -C "$ROOT" remote get-url origin 2>/dev/null)"
    [ -n "$_url" ] && mkdir -p "$(dirname "$clone")" && git clone -q "$_url" "$clone" 2>/dev/null \
      && printf 'review-seat: made the judge its own clone at %s\n' "$clone" >&2
  fi
  [ -d "$clone" ] || refuse "no review clone at $clone — a judge reviews a CLONE of the delivered commit, never a smith's worktree (git clone <remote> $clone)"
  local ws; ws="$(seat_room)"        # resolved once: the room says whose panes are the seat's own
  local pane; pane="$(seat_pane "$clone")"
  if [ -n "$pane" ]; then
    cmd_status "$clone"; return 0
  fi
  # A SEAT PANE WITH NO AGENT IS A DEAD SEAT (measured on the heart, 2026-11-14): close it, say so,
  # and raise a fresh agent in the same pass — otherwise nothing ever re-raises it and the watch
  # prompts a shell forever. It is closed when it stands in the seat's own `review` room, or when
  # herdr does not say which room it is in (an older herdr reports no workspace); a pane herdr
  # places in ANOTHER workspace is somebody else's and is not this door's to close (RULES/41). And
  # nothing is closed on a guess: `pane_verdict` must answer `dead` plainly.
  if [ -n "$ws" ]; then
    local dead room
    while IFS= read -r dead; do
      [ -n "$dead" ] || continue
      room="$(pane_room "$dead")"
      if [ -n "$room" ] && [ "$room" != "$ws" ]; then
        printf 'review-seat: pane %s stands in another workspace and holds no agent — left alone\n' "$dead" >&2
        continue
      fi
      if herdr pane close "$dead" >/dev/null 2>&1; then
        printf 'reaped[2]{pane,why}:\n  "%s","held no agent — a pane is not the seat; closed, and a fresh agent is raised"\n' "$dead"
      else
        printf 'review-seat: the dead pane %s could not be closed — raising a fresh agent beside it\n' "$dead" >&2
      fi
    done <<< "$(seat_panes "$clone" dead)"
  fi
  # The model is resolved for THIS seat, and named only if the catalogue lists it.
  # A SEAT CARRIES NO SECOND TOOLKIT: the clone ships its own `.pi/extensions` and settings.json
  # already names the primary's, so pi refuses to start with 40+ "Tool … conflicts" (measured
  # 2026-11-07, twice: on the operator's terminal and again after `git reset --hard` restored it).
  if [ -d "$clone/.pi/extensions" ]; then
    mv "$clone/.pi/extensions" "$clone/.pi/extensions.seat-hidden" 2>/dev/null \
      && printf 'review-seat: the clone'"'"'s own extensions set aside (settings.json loads the primary'"'"'s)\n' >&2
  fi
  local model; model="$(bash "$ROOT/bin/model/agent-model.sh" forseti --plain 2>/dev/null || true)"
  [ -n "$model" ] || die "no model resolved for the judge on this seat — bin/model/agent-model.sh forseti --explain"
  local charter; charter="$(write_charter "$clone")"
  # THE SEAT LAW: a seat gets its own machine state, so it never contends for the primary's helm.
  # `--primary` is the deliberate exception — a machine with NO live primary (measured: the heart's
  # lock named a dead pid on 2026-11-06) has nobody to drain the arm, so the review seat takes the
  # helm and says so. When a live primary DOES hold it, only the helm is refused: the seat is raised
  # as a plain seat, because a machine with no reviewer is the fault --primary exists to prevent.
  local seat_state="${YMIR_REVIEW_SEAT_STATE:-$STATE/review/seat}"
  local -a ENV_ARGS=()
  if [ "$PRIMARY" = 1 ]; then
    local lk owner
    lk="$(bash "$ROOT/bin/records/ymir-state.sh" lock lock-path 2>/dev/null || true)"
    owner="$(bash "$ROOT/bin/records/ymir-state.sh" lock owner 2>/dev/null || true)"
    if [ -n "$lk" ] && [ -n "$owner" ] && [ -r "/proc/$owner/stat" ]; then
      # A LIVE PRIMARY KEEPS THE HELM — and the seat is STILL RAISED (2026-11-14). Refusing every
      # run while a primary stands left the machine with no reviewer at all, which is the opposite
      # of what --primary was asked for. The helm is the only thing that may not be taken, so the
      # seat is raised as a plain seat with its own state and the refusal is said out loud.
      printf 'helm[2]{owner,decision}:\n  "%s","a live primary holds the lock — the helm is not taken; the seat is raised as a plain seat"\n' "$owner"
      PRIMARY=0
    else
      printf 'seat[1]{helm}:
  "primary — no live lock owner on this machine, so the review seat drains the arm itself"\n'
    fi
  fi
  if [ "$PRIMARY" = 0 ]; then
    mkdir -p "$seat_state" || die "cannot create the seat's private state at $seat_state"
    ENV_ARGS=(--env "BROKK_MACHINE_STATE_DIR=$seat_state" --env "BROKK_STATE_OVERRIDE=$seat_state")
  fi

  # ONE ROOM, SHARED: the judge and every smith live together in the workspace labelled
  # `$WORKSPACE_LABEL` ("review"), one TAB each — never beside the operator, never a workspace per
  # seat. The Allfather, 2026-11-07: "its only the smith. not the reviwer" — because this door made
  # its OWN workspace and the room he was watching held only smiths.
  if [ -z "$ws" ]; then
    local ws_out
    ws_out="$(herdr workspace create --cwd "$clone" --label "$WORKSPACE_LABEL" --no-focus \
                "${ENV_ARGS[@]}" 2>/dev/null)" \
      || die "herdr workspace create failed — is a herdr server running here?"
    ws="$(printf '%s' "$ws_out" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("result",{}).get("workspace",{}).get("workspace_id",""))' 2>/dev/null || true)"
  fi
  [ -n "$ws" ] || die "no '$WORKSPACE_LABEL' workspace and none could be created"

  local pane_out
  pane_out="$(herdr tab create --workspace "$ws" --cwd "$clone" 2>/dev/null \
    | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("result",{}).get("root_pane",{}).get("pane_id",""))' 2>/dev/null || true)"
  [ -n "$pane_out" ] || die "the room $ws gave no pane for the judge"

  # The name must be unique among live agents: 'pi' collided with every seat already in the room.
  local start_err=""
  if ! start_err="$(herdr agent start reviewer --kind pi --pane "$pane_out" -- --model "$model" \
        --append-system-prompt "$ROLE_FILE" --append-system-prompt "$charter" 2>&1 >/dev/null)"; then
    die "herdr agent start failed for pane $pane_out (model $model) — $(first_error_line "$start_err")"
  fi
  # Seating without verifying leaves an idle agent — the hard contract of the herdr skill.
  local tries=0 st=""
  while [ "$tries" -lt 20 ]; do
    st="$(pane_state "$pane_out")"
    case "$st" in working|idle|done|blocked) break ;; esac
    tries=$((tries + 1)); sleep 0.5
  done
  # pi DIES AT START and the pane holds the reason. The keeper used to say only "agent start failed",
  # which names nothing to fix (RULES/13 is the measured cause: two extension sets, one tool name).
  case "${st:-}" in
    working|idle|done|blocked) ;;
    *) die "no agent took the seat in pane $pane_out (state: ${st:-none}) — the pane says: $(pane_error_line "$pane_out")" ;;
  esac
  printf 'seat[5]{clone,pane,workspace,model,state}:\n  "%s","%s","%s","%s","%s"\n' \
    "$clone" "$pane_out" "$ws" "$model" "$st"
}

cmd_ask() {
  local pr="${1:-}"; shift || true
  local clone=$DEFAULT_CLONE WAIT=0
  while [ $# -gt 0 ]; do case "$1" in --clone) clone="${2:-}"; shift 2 ;; --wait) WAIT=1; shift ;; *) shift ;; esac; done
  [ -n "$pr" ] || usage "ask needs a PR number"
  need_herdr
  local pane; pane="$(seat_pane "$clone")"
  [ -n "$pane" ] || refuse "the judge is not seated in $clone — review-seat.sh ensure first"
  local line="Review PR #$pr. Fetch its head, run the rules floor and the gates YOURSELF here, then write ONE verdict to $STATE/eindri-reports/pr-$pr-review.md whose first line is PASS or REFUSE. Merge nothing; if you need a hand, ask the lock owner with bin/seat/lock-ask.sh."
  line="$(YMIR_MSG_FROM="${YMIR_MSG_FROM:-script review-seat, Forseti door}" bash "$(dirname "${BASH_SOURCE[0]}")/../agents/msg-origin.sh" "$line")"   # where it came from (2026-11-14)
  if [ "$WAIT" = 1 ]; then
    herdr agent prompt "$pane" "$line" --wait --until working >/dev/null 2>&1 \
      || die "the judge did not take the prompt (pane $pane)"
  else
    herdr agent prompt "$pane" "$line" >/dev/null 2>&1 || die "the judge did not take the prompt (pane $pane)"
  fi
  printf 'asked[3]{pane,pr,state}:\n  "%s","%s","prompted"\n' "$pane" "$pr"
}

cmd_close() {
  need_herdr
  local ws; ws="$(seat_room)"
  [ -n "$ws" ] || { printf 'seat[2]{workspace,state}:\n  "%s","absent"\n' "$WORKSPACE_LABEL"; return 0; }
  herdr workspace close "$ws" >/dev/null 2>&1 || die "herdr refused to close $ws"
  printf 'seat[2]{workspace,state}:\n  "%s","closed"\n' "$WORKSPACE_LABEL"
}

# ── durable and visible (the Allfather, 2026-11-06: "it should run in herdr so i can see it") ──
# A pane created by an ssh command dies with the session, and a headless agent is invisible. So the
# shape is two USER units: the herdr SERVER as a service (the panes outlive every client), and a
# keeper timer that re-raises the seat when it is gone. Nothing here takes the helm by itself —
# `ensure --primary` decides that, and refuses when a live primary holds the lock.
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
install_units() {
  local clone=$1 primary=$2
  mkdir -p "$UNIT_DIR" || die "cannot create $UNIT_DIR"
  cat >"$UNIT_DIR/herdr-server.service" <<UNIT
[Unit]
Description=herdr server — the panes outlive every client (the review seat lives in one)

[Service]
Type=simple
# A server already running is not a fault: the guard sleeps instead of starting a second one.
ExecStart=/bin/bash -lc 'herdr status server >/dev/null 2>&1 && exec sleep infinity || exec herdr server'
Restart=on-failure
RestartSec=15

[Install]
WantedBy=default.target
UNIT
  # the keeper unit is the register's (config/units.yaml: review-seat); the herdr server above is not a
  # Ymir tree and stays as written. The writer renders against the PINNED runtime (plan 269).
  bash "$ROOT/bin/engine/units.sh" write review-seat --set "CLONE=$clone" --set "PRIMARY=${primary:+ --primary}" --no-restart >/dev/null \
    || die "units.sh could not write review-seat"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now herdr-server.service >/dev/null 2>&1 || printf 'review-seat: WARNING — herdr-server.service did not start (a server may already be running; the guard sleeps in that case)\n' >&2
  systemctl --user enable --now review-seat.timer >/dev/null 2>&1 || die "the keeper timer could not be enabled ($UNIT_DIR/review-seat.timer)"
  printf 'units[4]{herdr_server,keeper_timer,clone,helm}:\n  "%s","%s","%s","%s"\n' \
    "$(systemctl --user is-active herdr-server.service 2>/dev/null | head -1)" \
    "$(systemctl --user is-active review-seat.timer 2>/dev/null | head -1)" \
    "$clone" "$([ -n "$primary" ] && echo primary || echo seat)"
}
unit_status() {
  printf 'units[3]{herdr_server,keeper_timer,next}:\n  "%s","%s","%s"\n' \
    "$(systemctl --user is-active herdr-server.service 2>/dev/null | head -1)" \
    "$(systemctl --user is-active review-seat.timer 2>/dev/null | head -1)" \
    "$(systemctl --user list-timers review-seat.timer --no-pager 2>/dev/null | sed -n '2p' | awk '{print $1, $2, $3}')"
}
uninstall_units() {
  systemctl --user disable --now review-seat.timer >/dev/null 2>&1 || true
  rm -f "$UNIT_DIR/review-seat.service" "$UNIT_DIR/review-seat.timer"
  systemctl --user daemon-reload 2>/dev/null || true
  printf 'units[2]{keeper_timer,state}:\n  "%s","removed (herdr-server.service left in place)"\n' "$UNIT_DIR/review-seat.timer"
}

case "${1-}" in
  --install-unit) shift || true; PRIMARY_ARG=""
                  while [ $# -gt 0 ]; do case "$1" in --primary) PRIMARY_ARG=1; shift ;; --clone) CLONE_ARG="${2:-}"; shift 2 ;; *) shift ;; esac; done
                  install_units "${CLONE_ARG:-$DEFAULT_CLONE}" "$PRIMARY_ARG"; exit 0 ;;
  --unit-status)  unit_status; exit 0 ;;
  --uninstall-unit) uninstall_units; exit 0 ;;
esac

ACTION="${1:-status}"; shift || true
case "$ACTION" in
  status)  cmd_status "$@" ;;
  ensure)  cmd_ensure "$@" ;;
  ask)     cmd_ask "$@" ;;
  charter) cmd_charter "$@" ;;
  close)   cmd_close "$@" ;;
  *) usage "unknown action '$ACTION' — status | ensure | ask | charter | close" ;;
esac
