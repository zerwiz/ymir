#!/usr/bin/env bash
# report.sh — THE handoff door. A worker that stops writes one of these, and this is the only way it
# reaches the shelf the digest reads.
#
# WHY THIS FILE EXISTS (documentation design, 2026-11-01): the design names one broken link — "handoff:
# 0 files where the idea says reports live". The brief already carried the path; nothing wrote it. A link
# with no door is a hope.
#
# THE SEVEN FIELDS (Project Handoff spec, hodd/docs/documentation-design.md §5):
#   id · state · what changed · what was verified · what was NOT verified · the next step · pointers
#
# The report is APPEND-ONLY (Rule 06): a correction is a new section, never an edit.
#
# Usage:
#   report.sh write <id> --state done|blocked|needs-decision \
#          --changed "<files/systems>" --verified "<command → result>" \
#          --not-verified "<what and why>" --next "<one imperative sentence>" \
#          [--pointers "plan:147 · card:INV-3 · docs/fixes/…"] [--actor <name>]
#   report.sh show <id>
#   report.sh list                      # every handoff on the shelf
#   report.sh missing <id>...           # which of these errands have no report (exit 1 if any)
#   report.sh check <id>                # exit 0 only when a report exists with all seven fields
#
# Exit: 0 ok · 1 refused/missing · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
SHELF="$STATE/eindri-reports"
mkdir -p "$SHELF" 2>/dev/null || true

usage(){ sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }
now(){ date -Iseconds; }

write_one(){  # <id> [flags]
  local id="${1:?id}"; shift
  local state="" changed="" verified="" notver="" next="" pointers="" actor="${YMIR_ACTOR:-worker}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --state) state="${2-}"; shift 2 ;;
      --changed) changed="${2-}"; shift 2 ;;
      --verified) verified="${2-}"; shift 2 ;;
      --not-verified) notver="${2-}"; shift 2 ;;
      --next) next="${2-}"; shift 2 ;;
      --pointers) pointers="${2-}"; shift 2 ;;
      --actor) actor="${2-}"; shift 2 ;;
      *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
    esac
  done
  case "$state" in done|blocked|needs-decision) ;; *) printf 'error: --state must be done, blocked or needs-decision (got "%s")\n' "$state" >&2; exit 2 ;; esac
  [ -n "$changed" ]  || { printf 'error: --changed is required — the files and systems you touched\n' >&2; exit 2; }
  [ -n "$verified" ] || { printf 'error: --verified is required — the commands you ran and what they printed, never "tested"\n' >&2; exit 2; }
  [ -n "$next" ]     || { printf 'error: --next is required — one imperative sentence for the next hand\n' >&2; exit 2; }
  local f="$SHELF/$id.md"
  {
    printf '\n## %s — %s\n\n' "$(now)" "$state"
    printf '```\nhandoff[7]{field,value}:\n'
    printf '  "id","%s"\n' "$id"
    printf '  "state","%s"\n' "$state"
    printf '  "actor","%s"\n' "$actor"
    printf '  "changed","%s"\n' "${changed//\"/\'}"
    printf '  "verified","%s"\n' "${verified//\"/\'}"
    printf '  "not_verified","%s"\n' "${notver//\"/\'}"
    printf '  "next","%s"\n' "${next//\"/\'}"
    printf '  "pointers","%s"\n' "${pointers//\"/\'}"
    printf '```\n'
  } >>"$f"
  printf 'report[1]{id,file,state}:\n  "%s","%s","%s"\n' "$id" "${f#"$ROOT"/}" "$state"
}

case "${1:-}" in
  write) shift; write_one "$@" ;;
  show)  f="$SHELF/${2:?id}.md"; [ -r "$f" ] || { printf 'report: no handoff for %s\n' "$2" >&2; exit 1; }; cat "$f" ;;
  list)  ls -1 "$SHELF"/*.md 2>/dev/null | while read -r f; do printf '  %s\n' "$(basename "$f" .md)"; done; \
         [ -n "$(ls -A "$SHELF" 2>/dev/null)" ] || printf '  (none — the handoff shelf is empty)\n' ;;
  missing)
    shift; rc=0
    for id in "$@"; do [ -r "$SHELF/$id.md" ] || { printf '  "%s","no handoff"\n' "$id"; rc=1; }; done
    exit "$rc" ;;
  check)
    id="${2:?id}"; f="$SHELF/$id.md"
    [ -r "$f" ] || { printf 'report: %s has no handoff\nhelp: report.sh write %s --state … --changed … --verified … --next …\n' "$id" "$id" >&2; exit 1; }
    for k in id state changed verified not_verified next pointers; do
      grep -q "\"$k\"," "$f" || { printf 'report: %s is missing the field %s\n' "$id" "$k" >&2; exit 1; }
    done
    printf 'report[1]{id,state}: "ok"\n' >/dev/null; printf 'report: %s complete\n' "$id" ;;
  *) usage; exit 2 ;;
esac
