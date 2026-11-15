#!/usr/bin/env bash
# eindri-send.sh — the DATA plane: hand a seated worker one attributed line, safely.
#
#   bin/agents/eindri-send.sh [--from "<who>"] [--machine <name>] [--wait <seconds>] \
#                             <pane>|<machine>:<pane> "<text>"
#
# The agent reads it as a new turn (herdr steers the running agent); the reply is read with
# `herdr agent read`. This is how the helm talks to a worker, and plan 293 part 5 makes three
# rules part of the door instead of three paragraphs in a runbook:
#
#   LOOK BEFORE YOU TYPE. `herdr agent prompt` APPENDS to whatever stands in the box and no
#   verb clears it, so a brief typed blindly lands inside the operator's half-written sentence
#   (measured 2026-11-14: a wrong brief, a stop, and the runbook gained a paragraph). The door
#   reads the box with bin/seat/herdr-editor.py and REFUSES when it holds text. It never
#   clears it — the words in a box may be the Allfather's.
#
#   A SEND IS NOT A LANDING. A prompt that arrives before the agent is ready is lost silently,
#   so the door waits (default 20s) and then asks THREE witnesses, in order: `herdr agent get`,
#   the screen, and the box itself. 2026-11-14: three new workers read `idle` while their screens
#   showed a spinner, so the helm resent and each got two briefs — the screen is read before any
#   resend. And a prompt sent while the harness is still starting can sit TYPED in the box with
#   no spinner and an `idle` status, so the box is read too: text there means "press Enter, never
#   retype"; an empty box means the line was lost and it is sent once more; an unreadable box
#   means neither, because a duplicate costs more than a retry. A spinner or `Working` on the
#   screen counts as landed.
#
#   SPEAK THE FAR SIDE'S VERBS. On another machine the road is ssh plus ITS herdr. 0.9.x has
#   `agent prompt`; 0.7.x has `agent send` and needs `pane send-keys <pane> Enter` to submit.
#   Which one it is, is PROBED from `herdr agent --help` (never from a version table): measured
#   on both shapes 2026-11-14. Machine names resolve through the home's fleet registry
#   (hodd/data/fleet.json → user@tailnet); an unknown name is refused, never guessed.
#
# Every line is stamped with where it came from by bin/agents/msg-origin.sh. --from, or
# YMIR_MSG_FROM, names the sender; --from "" is not a way to strip the stamp (YMIR_MSG_STAMP=0
# is, and it exists for tests and for a caller that already stamped).
#
# Report (TOON, one row). `resent` is `no` (nothing was needed), `copy` (the line was lost and
# was sent once more), `enter` (the words stood in the box unsent, so Enter was pressed) or
# `none` (the box could not be read, so nothing was done):
#   eindri-send[1]{target,machine,pane,editor,road,sent,state,resent}:
#     "<pane>","this machine","<pane>","empty","prompt","working","no"
#
# Exit: 0 delivered · 2 usage · 3 refused (the box holds text, or no agent stands there)
#       4 the send itself failed · 5 sent, but the worker never showed it was working.
set -u
SELF="$(basename "$0")"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=bin/agents/msg-origin.sh
. "$ROOT/bin/agents/msg-origin.sh"

die() { printf '%s: %s\n' "$SELF" "$*" >&2; exit "${2:-2}"; }
have() { command -v "$1" >/dev/null 2>&1; }

MACHINE=""; WAIT="${EINDRI_SEND_WAIT:-20}"; RESEND=1
while [ $# -gt 0 ]; do
  case "$1" in
    --from)    export YMIR_MSG_FROM="${2-}"; shift 2 ;;
    --machine) MACHINE="${2-}"; shift 2 ;;
    --wait)    WAIT="${2-}"; shift 2 ;;
    --once)    RESEND=0; shift ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
TARGET="${1-}"; shift || true; TEXT="${*:-}"
[ -n "$TARGET" ] && [ -n "$TEXT" ] || die "usage: $SELF [--machine <name>] <pane>|<machine>:<pane> \"<text>\""
case "$TEXT" in *$'\e'*|*$'\r'*) die "refusing text with control sequences — a brief is plain text, the pane is a terminal" ;; esac
[ "${YMIR_MSG_STAMP:-1}" = 0 ] || TEXT="$(msg_stamp "$TEXT")"

# --- where the words go ---------------------------------------------------------------
# The fleet registry is the only source of machine names (never a table here). It is read at
# run time, and a machine that is not in it is refused by name.
HOME_DIR=""
# shellcheck source=bin/vault/hoard-lib.sh
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
have ymir_home_root && ymir_home_root HOME_DIR 2>/dev/null
REG="${YMIR_FLEET_REGISTRY:-${HOME_DIR:-}/hodd/data/fleet.json}"

fleet_machines() {  # one name per line
  [ -r "$REG" ] || return 0
  python3 - "$REG" <<'PY' 2>/dev/null
import json, sys
try:
    hosts = (json.load(open(sys.argv[1], encoding='utf-8')).get('hosts') or {})
except Exception:
    raise SystemExit(0)
for name in hosts:
    print(name)
PY
}

road_of() {  # <machine> → user@host, or nothing
  [ -r "$REG" ] || return 0
  python3 - "$REG" "$1" <<'PY' 2>/dev/null
import json, sys
try:
    h = (json.load(open(sys.argv[1], encoding='utf-8')).get('hosts') or {}).get(sys.argv[2]) or {}
except Exception:
    raise SystemExit(0)
user, host = h.get('user'), h.get('tailnet')
if user and host:
    print(f'{user}@{host}')
PY
}

is_machine() { fleet_machines | grep -qx -- "$1"; }

ME="$(hostname -s 2>/dev/null || uname -n)"
PANE="$TARGET"
if [ -z "$MACHINE" ]; then
  # `<machine>:<pane>` — a pane id carries ONE colon (w39:p1V); a road carries two or more,
  # so the split is unambiguous and the prefix must be a real machine (probed, not assumed).
  case "$TARGET" in
    *:*:*)
      prefix="${TARGET%%:*}"
      if is_machine "$prefix"; then MACHINE="$prefix"; PANE="${TARGET#*:}"
      else die "no road to '$prefix' — not a machine in the fleet registry (a pane id has one colon; '<machine>:<pane>' names a machine that exists)" 2; fi ;;
  esac
fi
if [ -n "$MACHINE" ] && ! is_machine "$MACHINE"; then
  die "no road to '$MACHINE' — the fleet registry names no such machine" 2
fi
REMOTE=0
if [ -n "$MACHINE" ] && [ "$MACHINE" != "$ME" ]; then
  REMOTE=1
  DEST="$(road_of "$MACHINE")"
  [ -n "$DEST" ] || die "no road to '$MACHINE' — the registry carries no user and tailnet name for it" 2
  have ssh || die "ssh not found — a road to another machine rides ssh"
fi

# herdr on the far side may need a login shell to be on PATH (measured 2026-11-14: the heart
# carries herdr in ~/.local/bin and a non-interactive ssh does not see it).
far() {  # far <command string> — run it on the far side, or here
  if [ "$REMOTE" = 1 ]; then
    # The command string travels as ONE shell word to the far shell: single-quoted, with the
    # quote itself escaped. Without this, `bash -lc herdr agent prompt …` hands bash only
    # `herdr` as its command (measured: the heart answered "no such file herdr agent").
    local q; q="$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
    ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new "$DEST" "bash -lc '$q'" 2>&1
  else
    bash -c "$1" 2>&1
  fi
}

# --- the probe: which send verb does this herdr have? ---------------------------------
# Asked of the herdr itself (`agent --help`), because a version table is a guess wearing a
# number. 0.9.x lists `prompt`; 0.7.x lists `send`.
VERBS="$(far 'herdr agent --help')"
ROAD=""
case "$VERBS" in
  *"prompt"*) ROAD=prompt ;;
esac
if [ -z "$ROAD" ]; then
  case "$VERBS" in *"send"*) ROAD=send ;; esac
fi
[ -n "$ROAD" ] || die "cannot find a way to speak to a pane there — 'herdr agent --help' names neither prompt nor send" 4
unset VERBS

# --- an agent must stand there ------------------------------------------------------
AGENT_JSON="$(far "herdr agent get $(printf '%q' "$PANE")")"
case "$AGENT_JSON" in
  *'"agent_status"'*) ;;
  *) die "no agent stands in $PANE — refusing to type into a bare terminal (herdr said: $(printf '%s' "$AGENT_JSON" | head -1 | cut -c1-120))" 3 ;;
esac

# --- the box, read once now and again after the send --------------------------------
# <verdict> TAB <what the box holds>. One reader for both roads: a far pane's tail is read
# there and judged here, so the door can never judge two boxes by two rules.
box() {
  if [ "$REMOTE" = 1 ]; then
    far "herdr pane read $(printf '%q' "$PANE") --lines 40" | python3 "$ROOT/bin/seat/herdr-editor.py" --stdin
  else
    python3 "$ROOT/bin/seat/herdr-editor.py" "$PANE" 2>&1
  fi
}
row_of_box() { sed -n '2p' | cut -d'"' -f4; }
draft_of_box() { sed -n '2p' | cut -d'"' -f6; }

EDITOR="$(box)"
VERDICT="$(printf '%s' "$EDITOR" | row_of_box)"; VERDICT="${VERDICT:-unknown}"
DRAFT="$(printf '%s' "$EDITOR" | draft_of_box)"
if [ "$VERDICT" = text ]; then
  printf '%s: REFUSED — the input box of %s already holds someone'"'"'s text.\n' "$SELF" "$PANE" >&2
  printf '  it reads: "%s"\n' "$DRAFT" >&2
  printf '  nothing was sent and nothing was cleared: those words may be the Allfather'"'"'s.\n' >&2
  printf '  clear or send it in the pane itself, then call again.\n' >&2
  exit 3
fi

# --- send ---------------------------------------------------------------------------
send_once() {
  local p q
  p="$(printf '%q' "$PANE")"; q="$(printf '%q' "$TEXT")"
  case "$ROAD" in
    prompt) far "herdr agent prompt $p $q" >/dev/null ;;
    send)   far "herdr agent send $p $q" >/dev/null && far "herdr pane send-keys $p Enter" >/dev/null ;;
  esac
}

status_of() {
  local j; j="$(far "herdr agent get $(printf '%q' "$PANE")")"
  printf '%s' "$j" | python3 -c 'import json,sys,re
raw=sys.stdin.read()
m=re.search(r"\{.*\}", raw, re.S)
try: d=json.loads(m.group(0)) if m else {}
except Exception: d={}
a=((d.get("result") or {}).get("agent") or {})
print(a.get("agent_status") or "unknown")' 2>/dev/null
}

# The screen is the second witness: `agent get` lags it (2026-11-14, three workers).
screen_busy() {
  far "herdr pane read $(printf '%q' "$PANE") --lines 12" | grep -qE '⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏|Working|queued|esc to interrupt'
}

# A TYPED BRIEF IS NOT A SENT ONE (measured by the helm, 2026-11-14). A prompt that arrives
# while pi is still starting can sit in the editor, visible above the footer, with no spinner
# and an `idle` status — typed, never submitted. So when the status is not `working` and the
# screen is quiet, the door asks the BOX before it asks for a second copy:
#   the box holds text  → our words are there, unsent: press Enter, never retype;
#   the box is empty    → the line was lost: send it once more;
#   the box is unreadable → neither, because a duplicate costs more than a retry: say so.
submit_key() { far "herdr pane send-keys $(printf '%q' "$PANE") Enter" >/dev/null; }

SENT=0; RESENT=no; STATE=""
send_once || die "the send failed — the far side refused it" 4
SENT=1
# RECORD THE WORD (2026-11-14, plan 275 item 8, carried in from main): the send is written to the
# fleet message log so Hlidskjalf's A2A panel shows the herdr traffic between agents. `from` is the
# stamp's own origin, so the log and the pane can never disagree. A send that failed writes nothing,
# and a log that cannot be written never fails the send — the message matters more than its record.
case "$TEXT" in
  '[from '*'] '*) _from="${TEXT#\[from }"; _from="${_from%%\]*}"; _text="${TEXT#*\] }" ;;
  *) _from="$(msg_origin)"; _text="$TEXT" ;;
esac
# The `pane` column is the DESTINATION — the pane the word landed in. A named target that is not a
# pane id has no known destination pane, and the sender's own pane is NOT a stand-in for it.
case "$PANE" in
  w[0-9]*:p[0-9]*) _pane="$PANE" ;;
  *) _pane="" ;;
esac
"$ROOT/bin/agents/msg-log.sh" record --from "$_from" --to "$TARGET" --pane "$_pane" "$_text" 2>/dev/null || true
sleep "$WAIT" 2>/dev/null || true
STATE="$(status_of)"
if [ "$STATE" != working ] && [ "$RESEND" = 1 ] && ! screen_busy; then
  AFTER="$(box)"; AVERDICT="$(printf '%s' "$AFTER" | row_of_box)"; AVERDICT="${AVERDICT:-unknown}"
  case "$AVERDICT" in
    text)
      submit_key || die "the Enter key was refused — the line stands in the box, unsent" 4
      RESENT=enter ;;
    empty)
      send_once || die "the resend failed — the far side refused it" 4
      RESENT=copy ;;
    *)
      RESENT=none ;;
  esac
  sleep "$WAIT" 2>/dev/null || true
  STATE="$(status_of)"
fi

printf 'eindri-send[1]{target,machine,pane,editor,road,sent,state,resent}:\n'
printf '  "%s","%s","%s","%s","%s","%s","%s","%s"\n' \
  "$TARGET" "${MACHINE:-this machine}" "$PANE" "$VERDICT" "$ROAD" \
  "$([ "$SENT" = 1 ] && printf sent || printf none)" "$STATE" "$RESENT"
if [ "$VERDICT" = unknown ]; then
  printf 'help: the input box of %s could not be read, so it may not have been empty — check the pane\n' "$PANE" >&2
fi
[ "$STATE" = working ] && exit 0
case "$RESENT" in
  enter) printf '%s: the brief stood in %s unsent, so Enter was pressed — it has not read `working` yet\n' "$SELF" "$PANE" >&2 ;;
  copy)  printf '%s: the line was lost, so it was sent once more — %s still does not read `working`\n' "$SELF" "$PANE" >&2 ;;
  none)  printf '%s: %s does not read `working`, the screen is quiet and the box could not be read — nothing was re-sent, read the pane\n' "$SELF" "$PANE" >&2 ;;
     *)  printf '%s: sent, but %s does not read `working` — it may not have taken the line\n' "$SELF" "$PANE" >&2 ;;
esac
exit 5
