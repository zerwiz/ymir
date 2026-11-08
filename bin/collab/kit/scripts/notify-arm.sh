#!/usr/bin/env bash
# notify-arm.sh — hand a gate's message to the ARM HOLDER, never to whoever happened to type the command.
#
# WHY (the Allfather, 2026-11-08): *"they answering me instead of the hand that holds the … arm — it needs to
# inject the messages into the arm holder's chat window, also to the orchestrator that we have deployed per
# project."* A gate that prints at the person who typed `git commit` is a gate that shouts at the wrong room:
# the operator reads a refusal meant for an agent, and the agent — the hand holding the lock and the arm —
# never hears that its work was stopped.
#
# THE GROUND IS THE HOUSE'S OWN, never a new bus:
#   the arm    <state>/.arm.lease          (pid, starttime, state=) — is anybody holding it?
#   the queue  <state>/.wake-queue         (the arm's own inbox, DRAINED INTO THE SESSION WINDOW)
#   the seat   $YMIR_HOME/bin/agents/brokk-send.sh <id>   (a registered home, when one is named)
#   the card   <repo>/.well-known/agent-card.json         (where a project's orchestrator answers)
#
# DELIVERY, in the order it is attempted — every step is resolved, never guessed:
#   1 · the arm holder      one line appended to <state>/.wake-queue. The drain prints it as
#                           `WAKE KIT …` in the arm holder's chat window. This is the house's durable lane.
#   2 · the estate          the project's AREAS estate, asked of the house's own door
#                           `bin/agents/areas.sh estate <path>` — one line, so the arm holder reads the shape of
#                           the project with the refusal: `areas: 18 · 4 held · 0 unproved · 0 waived · 0 na · 14
#                           unheld`. Where the refusal NAMES AN AREA (`tenancy (unheld): <path>`), the notice
#                           also carries the one command that fixes it: `bin/agents/areas.sh call <project> <area>`.
#   3 · the orchestrator    the project's orchestrator, declared in ONE place: `orchestrator:` in the
#                           repository's `areas/agents.yaml`, or `$YMIR_ORCHESTRATOR_CMD` (explicit).
#                           A URL is spoken to over A2A; a seat id is nudged through brokk-send.sh.
#   4 · nobody declared     the notice still travels to the arm, and its line ends `orchestrator=none`,
#                           because a silently undelivered notice is the fault this door exists to end.
#
# LAWS IT HOLDS:
#   1 · It never breaks a git operation. Every failure exits 0 and says why only when KIT_NOTIFY_DEBUG=1.
#      (KIT_NOTIFY_STRICT=1 turns a failed delivery into a refusal, for a house that wants proof of delivery.)
#   2 · No address leaks: the line names the repository, the gate and the first line of the message — never a
#      host, a port, a path of the house or a person (RULES/39).
#   3 · One notice per message: an identical line already last in the queue is not appended twice.
#   4 · No arm, no shout: with no live arm the door is silent by construction — there is nobody to inject into.
#
# Usage: notify-arm.sh <gate> <message>…      ·  notify-arm.sh --who  (what it resolves, and why)
# Exit: 0 always (delivered, or explained on stderr under KIT_NOTIFY_DEBUG) · 1 only under KIT_NOTIFY_STRICT.
set -uo pipefail

DEBUG="${KIT_NOTIFY_DEBUG:-0}"
STRICT="${KIT_NOTIFY_STRICT:-0}"
say() { [ "$DEBUG" = 1 ] && printf 'notify-arm: %s\n' "$*" >&2; return 0; }

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo="$(basename "$root")"
# ---- where the arm lives -----------------------------------------------------------------------------
resolve_state() {
  local c
  for c in "${YMIR_STATE_DIR:-}" "${YMIR_HOME:+$YMIR_HOME/state}" \
           "$HOME/Documents/ymirhome/state" "$HOME/ymirhome/state"; do
    [ -n "$c" ] && [ -d "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}
state="$(resolve_state || true)"

# a live arm: the lease must name a pid that still exists
arm_live() {
  [ -n "$state" ] || return 1
  local lease="$state/.arm.lease" pid
  [ -r "$lease" ] || return 1
  pid="$(sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' "$lease" | head -1)"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

# ---- the estate: what this project's areas actually say ------------------------------------------------
# The house's own door answers, never a second parser. `areas.sh estate <path>` resolves the project from the
# repository's own path, so no id is guessed and no registry is restated here.
area_door() {
  local c
  for c in "${YMIR_CODE_ROOT:-}/bin/agents/areas.sh" "$HOME/ymir/bin/agents/areas.sh"; do
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

estate_facts() {   # prints "<project> <areas> <held> <unproved> <waived> <na> <unheld>"
  local door; door="$(area_door)" || return 1
  local out
  out="$(cd "$root" && bash "$door" estate "$root" 2>/dev/null | tail -1)" || return 1
  [ -n "$out" ] || return 1
  printf '%s\n' "$out" | tr -d '"' | tr ',' ' '
}

# the area a refusal names, when it names one (`tenancy (unheld): apps/…`)
named_area() { printf '%s' "$first" | grep -oE '[a-z0-9_-]+ \((unheld|unproved|waived)\)' | head -1 | cut -d' ' -f1; }

# ---- the project's orchestrator, declared in one place ------------------------------------------------
declared_orchestrator() {
  [ -n "${YMIR_ORCHESTRATOR_CMD:-}" ] && { printf 'cmd:%s\n' "$YMIR_ORCHESTRATOR_CMD"; return 0; }
  local f="$root/areas/agents.yaml" v
  [ -r "$f" ] || return 1
  v="$(sed -n 's/^orchestrator:[[:space:]]*//p' "$f" | head -1 | sed 's/^"//; s/"$//' | tr -d '\r')"
  [ -n "$v" ] && { printf '%s\n' "$v"; return 0; }
  return 1
}

deliver_arm() {
  arm_live || { say "no live arm in ${state:-<unresolved>} — nobody to inject into"; return 1; }
  mkdir -p "$state" 2>/dev/null
  queue_append "$line"
}

deliver_orchestrator() {
  local target; target="$(declared_orchestrator)" || { say "no orchestrator declared (areas/agents.yaml, YMIR_ORCHESTRATOR_CMD)"; return 1; }
  case "$target" in
    cmd:*)
      local cmd="${target#cmd:}"
      sh -c "$cmd \"\$1\"" _ "$line" >/dev/null 2>&1 && { say "delivered through YMIR_ORCHESTRATOR_CMD"; return 0; }
      say "YMIR_ORCHESTRATOR_CMD failed"; return 1 ;;
    http://*|https://*)
      # A2A is asked, never assumed: an unauthenticated POST is a probe, and the card is the only anonymous
      # answer. We therefore deliver a *record* locally and name the card, rather than inventing a grant.
      local card="$root/.well-known/agent-card.json"
      if [ -r "$card" ]; then
        say "orchestrator is a card ($target) — no grant exists for a call; the notice is recorded in the arm lane"
        return 1
      fi
      say "orchestrator URL declared but the repository carries no card"; return 1 ;;
    *)
      # a seat id in a registered home
      local send="${YMIR_HOME:-$HOME/Documents/ymirhome}/../ymir/bin/agents/brokk-send.sh"
      [ -n "${YMIR_CODE_ROOT:-}" ] && [ -x "$YMIR_CODE_ROOT/bin/agents/brokk-send.sh" ] && send="$YMIR_CODE_ROOT/bin/agents/brokk-send.sh"
      if [ -x "$send" ] && bash "$send" "$target" "$line" >/dev/null 2>&1; then
        say "delivered to the seat '$target' through brokk-send.sh"; return 0
      fi
      say "orchestrator '$target' declared, but no door answered"; return 1 ;;
  esac
}

if [ "${1:-}" = "--who" ]; then
  printf 'notify-arm[5]{key,value}:\n'
  printf '  "repo","%s"\n' "$repo"
  printf '  "state","%s"\n' "${state:-unresolved}"
  arm_live && printf '  "arm","live (%s)\n' "$state/.arm.lease" || printf '  "arm","none — the door is silent"\n'
  printf '  "orchestrator","%s"\n' "$(declared_orchestrator || printf 'none declared')"
  exit 0
fi

queue_append() {   # <line> — one notice per message, never the same line twice in a row
  local l="$1" q="$state/.wake-queue"
  arm_live || return 1
  if [ -r "$q" ] && [ "$(tail -1 "$q" 2>/dev/null)" = "$l" ]; then say "already last in the queue: $l"; return 0; fi
  printf '%s\n' "$l" >> "$q" 2>/dev/null || { say "the wake queue is not writable: $q"; return 1; }
  say "delivered to the arm holder's window: $l"
  return 0
}

gate="${1:-gate}"; shift || true
message="${*:-}"
[ -n "$message" ] || { say "no message — nothing to deliver"; exit 0; }
first="$(printf '%s' "$message" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-240)"
line="KIT $repo · $gate · $first"

ok=0
deliver_arm && ok=1

# the estate travels with the refusal, and the remedy is named when the gate named an area
if facts="$(estate_facts)"; then
  set -- $facts; project="${1:-}"; areas="${2:-0}"; held="${3:-0}"; unproved="${4:-0}"; waived="${5:-0}"; na="${6:-0}"; unheld="${7:-0}"
  queue_append "KIT $repo · estate · areas: $areas · $held held · $unproved unproved · $waived waived · $na na · $unheld unheld ($project)" && ok=1
  area="$(named_area)"
  if [ -n "$area" ] && [ -n "$project" ]; then
    queue_append "KIT $repo · remedy · $area is unheld — shape it, then apply it: bash bin/agents/areas.sh call $project $area (or carry the file in a held area)" && ok=1
  fi
fi

deliver_orchestrator && ok=1
[ "$ok" = 1 ] && exit 0

if [ "$STRICT" = 1 ]; then
  printf 'notify-arm: no receiver took the notice (arm, orchestrator) — refused under KIT_NOTIFY_STRICT\n' >&2
  exit 1
fi
exit 0
