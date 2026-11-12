#!/usr/bin/env bash
# rodd-helm.sh — Nanna's duty loop: she holds the helm and carries its five duties.
#
# Nanna is the agent inside Rödd (the voice). Holding the helm without the duties
# is the thing plan 254 refuses, so the loop lives HERE and it is THIN: it calls
# the doors that own each duty rather than re-implementing them.
#
#   drain      bin/time/saga-wake-drain.sh               read the wakes, ack the handled
#   answer     <lease state>/rodd/room.jsonl             append {ts,from,text}, never truncate
#   alarm      bin/notify/send.sh --key rodd:refusal:<sha>  (one toast per window, keyed)
#   dispatch   bin/agents/einherjar-spawn.sh             direct-PR / no-mistakes ONLY
#   refuse     bin/voice/rodd-arm.sh release             give the helm back when a duty is beyond her
#
# A refused wake is SPOKEN, never dropped: the refusal is written to the room and
# raised through the notify door, and the helm is released so the next seat can take it.
#
# A REFUSAL IS KEYED (plan 254 B7). The toast *"Rödd refuses a wake … please merge PR 999
# into main (no link)"* came back night after night because nothing keyed it: the same
# instruction, re-met, raised a fresh notification every time. Now every refusal goes
# through bin/notify/send.sh with `--key rodd:refusal:<sha of the instruction>`, so the
# same refused instruction is ONE toast per window — and ALWAYS one room line, because a
# refusal silenced on the desktop must still be on the record. The words are composed
# from the instruction and the reason; no fixed phrase lives in this file. The room is
# resolved from the `state=` the arm LEASE names — the lease is the authority,
# never a path — and the queue is drained/acked through the door, never edited.
#
# Usage:
#   rodd-helm.sh run          one duty pass: drain, answer, ack (exit 0)
#   rodd-helm.sh --check      the health surface (known role, writable room, drain door)
#   rodd-helm.sh --version
#
# Exit: 0 ok · 3 not the helm / no arm held · 1 refused-and-released · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

HOARD_LIB="$ROOT/bin/vault/hoard-lib.sh"
DRAIN="$ROOT/bin/time/saga-wake-drain.sh"
ARM="$ROOT/bin/voice/rodd-arm.sh"
# The mouth is the notify door, a setting so a test hands it a silent stand-in (2026-11-12:
# the suite's fake refusal once reached the operator's real desktop).
NOTIFY="${RODD_NOTIFY_DOOR:-$ROOT/bin/notify/send.sh}"
SPAWN="$ROOT/bin/agents/einherjar-spawn.sh"
LOCK_DOOR="$ROOT/bin/records/ymir-state.sh"

die()   { printf 'rodd-helm: %s\n' "$*" >&2; exit 1; }
refuse(){ printf 'rodd-helm: %s\n' "$*" >&2; exit 3; }

# ── the state and the room ──────────────────────────────────────────────────
resolve_state() {
  if [ -n "${BROKK_STATE_OVERRIDE:-}" ]; then
    STATE_ROOT="$BROKK_STATE_OVERRIDE"
    return 0
  fi
  if [ -r "$HOARD_LIB" ]; then
    # shellcheck source=../vault/hoard-lib.sh
    . "$HOARD_LIB"
    hoard_state_dir STATE_ROOT 2>/dev/null || STATE_ROOT=""
  fi
  [ -n "${STATE_ROOT:-}" ] || die "no state dir resolved — BROKK_STATE_OVERRIDE or the home resolver"
}

lease_field() {  # <file> <field>
  sed -n "s/.*\b$2=\([^ ]*\).*/\1/p" "$1" 2>/dev/null | head -1
}

resolve_room() {
  local lease="$STATE_ROOT/.arm.lease" lstate=""
  [ -r "$lease" ] || refuse "no arm lease at $lease — nobody is holding the arm"
  lstate="$(lease_field "$lease" state)"
  [ -n "$lstate" ] && [ -d "$lstate" ] \
    || refuse "the lease names state '$lstate', which is not a directory — the room cannot be resolved"
  ROOM_STATE="$lstate"
  ROOM="$lstate/rodd/room.jsonl"
}

room_append() {  # <from> <text> — one append-only line, never a truncation
  mkdir -p "$(dirname "$ROOM")" 2>/dev/null || return 1
  python3 - "$ROOM" "$1" "$2" <<'PY' || return 1
import json, sys, time
room, who, text = sys.argv[1:4]
with open(room, "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"ts": int(time.time()), "from": who, "text": " ".join(text.split())}, ensure_ascii=False) + "\n")
PY
}

# ── a refusal: one room line always, one keyed toast per window ─────────────
# The instruction is normalised before it is hashed — a leading ISO stamp and the
# queue's own tab-separated header are not part of what was asked — so the SAME request
# re-met tomorrow is the same key, and a different request is a different one.
instruction_of() {  # <wake line> → the words that were asked
  printf '%s' "$1" | awk -F'\t' '{print $NF}' \
    | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z?[[:space:]]+//' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'
}
refusal_key() {  # <instruction> → rodd:refusal:<sha>
  printf 'rodd:refusal:%s' "$(printf '%s' "$1" | sha256sum | cut -c1-16)"
}
refuse_aloud() {  # <reason> <wake line>
  local reason="$1" asked key
  asked="$(instruction_of "$2")"
  key="$(refusal_key "$asked")"
  room_append "Nanna" "refused ($reason): $asked [key $key]"
  [ -x "$NOTIFY" ] || [ -r "$NOTIFY" ] || return 0
  bash "$NOTIFY" --source rodd --severity MEDIUM --key "$key" --no-telegram \
    --message "Rödd refused: $asked — $reason" >/dev/null 2>&1 || true
}

# Her own notices come back to her through the queue (the notify door raises MEDIUM+ as
# a wake). A line she raised is HER word, already recorded — it is heard, never judged
# again, or one refusal would breed the next.
is_her_own() {
  case "$1" in
    *" notify rodd "*|*"notify rodd "*) return 0 ;;
    *) return 1 ;;
  esac
}

# ── the judgement a wake asks for ────────────────────────────────────────────
# A wake asking for a merge (or another act only the Allfather may do) is beyond
# her writ: refused aloud and the helm released. A wake asking for WORK may only
# be dispatched as direct-PR / no-mistakes — never a merge, never a local-only
# that writes nowhere, never money, never his voice (Rule 08).
is_beyond_her() {
  case "$1" in
    *merge*|*force[[:space:]]*push*|*force-push*|*reset*|*--no-verify*|*spend*|*deploy*|*production*|*rm[[:space:]]-rf*|*sudo*) return 0 ;;
    *) return 1 ;;
  esac
}

dispatch_requested() {  # <wake> — "errand:<id> project:<path> mode:<direct-PR|no-mistakes>"
  case "$1" in
    errand:*[[:space:]]project:*[[:space:]]mode:*) return 0 ;;
    *) return 1 ;;
  esac
}

dispatch_errand() {  # <wake>
  local wake="$1" id="" project="" mode=""
  id="$(printf '%s\n' "$wake" | sed -n 's/.*\berrand:\([^ ]*\).*/\1/p')"
  project="$(printf '%s\n' "$wake" | sed -n 's/.*\bproject:\([^ ]*\).*/\1/p')"
  mode="$(printf '%s\n' "$wake" | sed -n 's/.*\bmode:\([^ ]*\).*/\1/p')"
  [ -n "$id" ] && [ -n "$project" ] || { room_append "Nanna" "cannot dispatch — $wake names no errand or project"; return 1; }
  case "$mode" in
    direct-PR|no-mistakes) ;;
    *) refuse_aloud "mode '$mode' is not direct-PR or no-mistakes" "$wake"; return 1 ;;
  esac
  [ -x "$SPAWN" ] || { room_append "Nanna" "cannot dispatch — the errand door is missing"; return 1; }
  "$SPAWN" "$id" "$project" --mode "$mode" >/dev/null 2>&1 \
    && room_append "Nanna" "dispatched errand $id in $project (mode $mode)" \
    || refuse_aloud "Rödd's dispatch was refused" "errand $id in $project — the errand door refused it (no helm, no errand?)"
}

# ── one duty pass ─────────────────────────────────────────────────────────────
run_pass() {
  resolve_state
  resolve_room
  "$LOCK_DOOR" lock owned --shell-pid "$$" >/dev/null 2>&1 \
    || refuse "this session does not hold the helm — the wakes are the holder's to drain"

  local out line refused=0 answered=0
  out="$("$DRAIN" drain 2>/dev/null)" || true
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "WAKE "*) line="${line#WAKE }" ;;
      *) continue ;;
    esac
    [ -n "$line" ] || continue
    if is_her_own "$line"; then
      continue
    fi
    if is_beyond_her "$line"; then
      refuse_aloud "a merge, a force, a spend or a deploy is the Allfather's hand (Rule 08)" "$line"
      "$ARM" release >/dev/null 2>&1 || true
      printf 'rodd-helm: refused and released — %s\n' "$line" >&2
      refused=1
      break
    fi
    if dispatch_requested "$line"; then
      dispatch_errand "$line" || true
    fi
    room_append "Nanna" "heard: $line"
    answered=$((answered + 1))
  done <<<"$out"

  "$DRAIN" ack >/dev/null 2>&1 || true
  printf 'rodd-helm[1]{answered,refused}:\n  %s,%s\n' "$answered" "$refused"
  [ "$refused" = 0 ]
}

# ── the health surface ─────────────────────────────────────────────────────────
cmd_check() {
  resolve_state
  local lease="$STATE_ROOT/.arm.lease" role=""
  [ -r "$lease" ] || refuse "no arm lease — nobody is holding the arm"
  role="$(lease_field "$lease" role)"
  # A lease the daemon wrote before the hold took the helm (or from an older pinned runtime)
  # names no role; the hold's sidecar for the SAME session is the declaration then.
  if [ -z "$role" ] || [ "$role" = unknown ]; then
    local lsess side srole ssess
    lsess="$(lease_field "$lease" session)"; side="$STATE_ROOT/.arm.role"
    [ -r "$side" ] && { srole="$(lease_field "$side" role)"; ssess="$(lease_field "$side" session)"; }
    [ -n "${srole:-}" ] && [ -n "$lsess" ] && [ "${ssess:-}" = "$lsess" ] && role="$srole"
  fi
  [ -n "$role" ] || role=unknown
  case "$role" in
    rodd|counsellor|pi|opencode|claude|cursor|codex|grok|kimi|muse|hermes) : ;;
    *) refuse "the lease names role '$role', which is not a known holder role" ;;
  esac
  resolve_room
  mkdir -p "$(dirname "$ROOM")" 2>/dev/null || refuse "the room's shelf $(dirname "$ROOM") is not writable"
  [ -w "$(dirname "$ROOM")" ] || refuse "the room's shelf $(dirname "$ROOM") is not writable"
  [ -x "$DRAIN" ] || refuse "the drain door is missing ($DRAIN)"
  printf 'rodd-helm[1]{verdict,role,room,drain}:\n  "ok","%s","%s","%s"\n' "$role" "$ROOM" "$DRAIN"
  return 0
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  run|--once) shift; run_pass ;;
  --check|check) shift; cmd_check ;;
  *) printf 'error: unknown verb %s\nhelp: rodd-helm.sh [run|--check|--version]\n' "$1" >&2; exit 2 ;;
esac
