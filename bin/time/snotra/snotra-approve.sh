#!/usr/bin/env bash
# snotra-approve.sh — the operator's word, bound to the exact bytes of a letter.
#
# WHY: on 2026-10-23 a letter about how the company runs meetings reached the partners
# without the Allfather seeing it first. "I NEED TO APPROVE THE MAIL." So sending is no
# longer a verb anyone can call on a draft: it requires an APPROVAL RECORD whose hash
# matches the draft's exact content. Edit one character after approval and the approval
# no longer matches — the draft must be approved again.
#
#   snotra-approve.sh approve <draft-id>     # run by the operator, on his own word
#   snotra-approve.sh check   <draft-id>     # exit 0 only if approved AND unchanged
#   snotra-approve.sh list                   # what is approved, and what has changed
#   snotra-approve.sh revoke  <draft-id>
#   snotra-approve.sh whoami                 # the operator identity a record carries
#
# The record lives OUTSIDE git, in the state dir: an approval is an act, not a document.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MAIL="$ROOT/bin/time/snotra/mail-send.sh"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ymir/approvals"
mkdir -p "$STATE"

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
  if [ -n "${YMIR_HOME:-}" ] && [ -r "$YMIR_HOME/hodd/identity/operator.yaml" ]; then
    sed -n 's/^name:[[:space:]]*//p' "$YMIR_HOME/hodd/identity/operator.yaml" | head -1
  fi
}
now(){ "$ROOT/bin/time/sol.sh" now 2>/dev/null | sed -n 's/^  "utc","\(.*\)"/\1/p' | head -1; }

hash_of(){  # the exact raw of a draft
  local id="$1" raw
  raw="$(bash "$MAIL" raw "$id")" || { echo "approve: cannot read draft $id" >&2; exit 2; }
  printf '%s' "$raw" | sha256sum | cut -d' ' -f1
}

case "${1:-check}" in
  approve)
    id="${2-}"; [ -n "$id" ] || { echo "usage: snotra-approve.sh approve <draft-id>" >&2; exit 2; }
    h="$(hash_of "$id")"
    printf '{"draft":"%s","sha256":"%s","operator":"%s","approved_at":"%s"}\n' \
      "$id" "$h" "$(operator)" "$(now)" > "$STATE/$id.json"
    printf 'approved\t%s\t%s\n' "$id" "${h:0:16}"
    ;;
  check)
    id="${2-}"; [ -n "$id" ] || { echo "check: a draft id is required" >&2; exit 2; }
    f="$STATE/$id.json"; [ -r "$f" ] || { echo "check: NOT APPROVED — no approval record for $id" >&2; exit 1; }
    want="$(sed -n 's/.*"sha256":"\([a-f0-9]\{64\}\)".*/\1/p' "$f")"
    have="$(hash_of "$id")"
    [ "$want" = "$have" ] || { echo "check: STALE — the draft changed after approval; approve it again" >&2; exit 1; }
    echo "check: approved"
    ;;
  revoke)
    id="${2-}"; rm -f "$STATE/${id}.json"; echo "revoked: $id" ;;
  list)
    [ -d "$STATE" ] || { echo "nothing approved"; exit 0; }
    for f in "$STATE"/*.json; do [ -e "$f" ] || continue
      id="$(basename "$f" .json)"
      if out="$(bash "$0" check "$id" 2>&1)"; then printf 'OK      %s\n' "$id"; else printf 'STALE   %s  (%s)\n' "$id" "$out"; fi
    done ;;
  whoami) operator ;;
  *) sed -n '12,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
