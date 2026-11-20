#!/usr/bin/env bash
# snotra-approve.sh — the operator's word, bound to the exact bytes of what leaves.
#
# WHY: on 2026-10-23 a letter about how the company runs meetings reached the partners
# without the Allfather seeing it first. "I NEED TO APPROVE THE MAIL." So sending is no
# longer a verb anyone can call on a draft: it requires an APPROVAL RECORD whose hash
# matches the draft's exact content. Edit one character after approval and the approval
# no longer matches — the draft must be approved again.
#
# Since 2026-10-24 (plan 124 §7) the word covers EVERY outbound door, not just letters:
# `mail-send.sh send` and `calendar-invite.sh` both ask THIS file before acting, and a
# refusal is carved into the Runes as loudly as an approval. An approval is SINGLE USE:
# a second send of the same subject is refused (ALREADY SENT), never replayed.
#
#   snotra-approve.sh approve <draft-id>          # mail: bind the word to a live draft
#   snotra-approve.sh check   <draft-id>          # mail: exit 0 only if approved AND unchanged
#   snotra-approve.sh gate    mail <draft-id>     # mail: check, and RECORD a refusal
#   snotra-approve.sh consume mail <draft-id>     # mail: the send happened; the word is spent
#
#   snotra-approve.sh hold        <event-key> <payload-file>  # the event as it would be posted
#   snotra-approve.sh approve-event <event-key>               # bind the word to those bytes
#   snotra-approve.sh gate    event <event-key> [--bytes FILE] # check (a fresh render), record a refusal
#   snotra-approve.sh consume event <event-key>                # the invitation was posted
#
#   snotra-approve.sh list                        # what is approved, stale, or already spent
#   snotra-approve.sh revoke  <key>
#   snotra-approve.sh whoami                      # the operator identity a record carries
#
# The record lives OUTSIDE git, in the state dir: an approval is an act, not a document.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MAIL="$ROOT/systems/snotra/services/letters/mail-send.sh"
RUNES="$ROOT/bin/records/runes-append.sh"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root YMIR_HOME_R 2>/dev/null || true
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ymir/approvals"
PENDING="$STATE/pending"
mkdir -p "$STATE" "$PENDING"

# The home, through the ONE resolver (Rule 07): `$YMIR_HOME` is read below, so the
# file must resolve it rather than restate it. A guarded `-n` test is not a resolver.
if [ -z "${YMIR_HOME:-}" ]; then
  # shellcheck source=../../vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root YMIR_HOME || true
fi

operator(){
  local id="${YMIR_OPERATOR:-}"
  [ -n "$id" ] && { printf '%s' "$id"; return; }
  if [ -n "${YMIR_HOME_R:-}" ] && [ -r "$YMIR_HOME_R/hodd/identity/operator.yaml" ]; then
    sed -n 's/^name:[[:space:]]*//p' "$YMIR_HOME_R/hodd/identity/operator.yaml" | head -1
  fi
}
now(){ "$ROOT/bin/time/sol.sh" now 2>/dev/null | sed -n 's/^  "utc","\(.*\)"/\1/p' | head -1; }

record_of(){ printf '%s/%s.json' "$STATE" "$1"; }
spent_of(){  printf '%s/%s.sent' "$STATE" "$1"; }
held_of(){   printf '%s/%s.json' "$PENDING" "$1"; }

# the bytes the word is bound to: live mail bytes, or a held/rendered event payload
bytes_of(){  # <kind> <key> [bytes-file]
  local kind="$1" key="$2" from="${3-}"
  case "$kind" in
    mail)
      bash "$MAIL" raw "$key" || return 2 ;;
    event)
      if [ -n "$from" ]; then cat "$from"
      else cat "$(held_of "$key")" 2>/dev/null || return 2; fi ;;
    *) echo "approve: unknown subject kind '$kind' (mail|event)" >&2; return 2 ;;
  esac
}
hash_bytes(){ printf '%s' "$1" | sha256sum | cut -d' ' -f1; }
hash_of(){ local b; b="$(bytes_of "${@}")" || return 2; hash_bytes "$b"; }

# the one verdict. prints the reason to stderr and returns 1 on any refusal.
verdict(){  # <kind> <key> [bytes-file]
  local kind="$1" key="$2" from="${3-}" f want have spent
  f="$(record_of "$key")"
  [ -r "$f" ] || { printf 'NOT APPROVED — no approval record for %s; the operator approves with: snotra-approve.sh %s %s\n' \
                     "$key" "$([ "$kind" = event ] && echo approve-event || echo approve)" "$key" >&2; return 1; }
  spent="$(spent_of "$key")"
  if [ -r "$spent" ]; then
    printf 'ALREADY SENT — this approval was spent at %s; a second send needs a new word\n' \
      "$(sed -n 's/.*"spent_at":"\([^"]*\)".*/\1/p' "$spent" 2>/dev/null)" >&2
    return 1
  fi
  want="$(sed -n 's/.*"sha256":"\([a-f0-9]\{64\}\)".*/\1/p' "$f")"
  have="$(hash_of "$kind" "$key" "$from")" || { printf 'UNREADABLE — cannot read the current bytes of %s\n' "$key" >&2; return 1; }
  [ "$want" = "$have" ] || { printf 'STALE — the content changed after approval; approve it again\n' >&2; return 1; }
  return 0
}

# a refusal is evidence, not a mood: carve it. A ledger that cannot be written must
# not wedge the door, but it must say so out loud.
carve(){  # <event> <message>
  [ -x "$RUNES" ] || return 0
  bash "$RUNES" snotra-approve "$1" --message "$2" >/dev/null 2>&1 \
    || printf 'approve: the Runes ledger refused the entry (%s)\n' "$1" >&2
  return 0
}

write_record(){  # <kind> <key> <sha>
  printf '{"kind":"%s","key":"%s","draft":"%s","sha256":"%s","operator":"%s","approved_at":"%s"}\n' \
    "$1" "$2" "$2" "$3" "$(operator)" "$(now)" > "$(record_of "$2")"
  printf 'approved\t%s\t%s\t%s\n' "$1" "$2" "${3:0:16}"
}

case "${1:-check}" in
  approve|approve-event)
    kind=mail; [ "$1" = approve-event ] && kind=event
    key="${2-}"; [ -n "$key" ] || { echo "usage: snotra-approve.sh $1 <key>" >&2; exit 2; }
    h="$(hash_of "$kind" "$key")" || { echo "approve: cannot read the bytes of $key" >&2; exit 2; }
    rm -f "$(spent_of "$key")"   # a fresh word replaces a spent one, deliberately
    write_record "$kind" "$key" "$h"
    ;;
  check|check-mail)
    key="${2-}"; [ -n "$key" ] || { echo "check: a draft id is required" >&2; exit 2; }
    verdict mail "$key" || exit 1
    echo "check: approved"
    ;;
  gate)
    kind="${2-}"; key="${3-}"; [ -n "$kind" ] && [ -n "$key" ] || { echo "usage: snotra-approve.sh gate mail|event <key> [--bytes FILE]" >&2; exit 2; }
    from=""; [ "${4-}" = "--bytes" ] && from="${5-}"
    if why="$(verdict "$kind" "$key" ${from:+"$from"} 2>&1)"; then echo "gate: approved"; exit 0; fi
    carve gate-refused "REFUSED ${kind} ${key}: ${why}"
    printf '%s\n' "$why" >&2
    exit 1
    ;;
  consume)
    kind="${2-}"; key="${3-}"; [ -n "$kind" ] && [ -n "$key" ] || { echo "usage: snotra-approve.sh consume mail|event <key>" >&2; exit 2; }
    printf '{"spent_at":"%s","operator":"%s","kind":"%s","key":"%s"}\n' "$(now)" "$(operator)" "$kind" "$key" \
      > "$(spent_of "$key")"
    carve gate-spent "SPENT ${kind} ${key} by $(operator) after an approved send"
    printf 'consumed\t%s\t%s\n' "$kind" "$key"
    ;;
  hold)
    key="${2-}"; src="${3-}"
    [ -n "$key" ] && [ -r "$src" ] || { echo "usage: snotra-approve.sh hold <event-key> <payload-file>" >&2; exit 2; }
    cp -- "$src" "$(held_of "$key")"
    h="$(hash_bytes "$(cat -- "$(held_of "$key")")")"
    printf 'held\t%s\t%s\n' "$key" "${h:0:16}"
    ;;
  pending-of)
    key="${2-}"; [ -n "$key" ] || { echo "usage: snotra-approve.sh pending-of <event-key>" >&2; exit 2; }
    held_of "$key"
    ;;
  revoke)
    key="${2-}"; [ -n "$key" ] || { echo "usage: snotra-approve.sh revoke <key>" >&2; exit 2; }
    rm -f "$(record_of "$key")" "$(spent_of "$key")"
    echo "revoked: $key" ;;
  list)
    for f in "$STATE"/*.json; do [ -e "$f" ] || continue
      id="$(basename "$f" .json)"
      kind="$(sed -n 's/.*"kind":"\([a-z]*\)".*/\1/p' "$f")"; kind="${kind:-mail}"
      if [ -r "$(spent_of "$id")" ]; then printf 'SENT    %-5s %s\n' "$kind" "$id"; continue; fi
      if out="$(verdict "$kind" "$id" 2>&1)"; then printf 'OK      %-5s %s\n' "$kind" "$id"
      else
        case "$out" in
          *UNREADABLE*) printf 'GONE    %-5s %s  (the subject no longer exists — already sent or discarded)\n' "$kind" "$id" ;;
          *)            printf 'STALE   %-5s %s  (%s)\n' "$kind" "$id" "$out" ;;
        esac
      fi
    done 2>/dev/null || true
    [ -n "$(ls "$STATE"/*.json 2>/dev/null)" ] || echo "nothing approved" ;;
  whoami) operator ;;
  *) sed -n '12,32p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
