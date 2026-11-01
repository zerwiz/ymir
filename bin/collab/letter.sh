#!/usr/bin/env bash
# letter.sh — the collaboration letter, rendered from a template and left as a DRAFT in the gate.
#
#   letter.sh --to <address> --person "<name>" [--projects "a, b"] [--from "<sender>"]
#             [--attach FILE ...] [--template FILE] [--dry-run]
#
# It drafts; it never sends. Sending is the operator's word, and it goes through the approval gate:
#
#   systems/snotra/services/letters/mail-send.sh send <draft-id>
#
# The rendered letter is kept in the hoard (`hodd/state/collab/letters/`) so the record of what was asked
# survives the draft.
#
# Exit: 0 drafted (or rendered) · 1 a required input is missing or the gate refused · 2 usage.
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root() { local d; d="$_d"; while [ "$d" != "/" ]; do [ -d "$d/RULES" ] && [ -d "$d/.pi" ] && { printf '%s' "$d"; return; }; d="$(dirname "$d")"; done; printf '%s' "$(cd "$_d/../.." && pwd)"; }
ROOT="$(_root)"
MAIL="$ROOT/systems/snotra/services/letters/mail-send.sh"
TEMPLATE="$_d/letters/collaboration-files.md"

to="" person="" projects="the repositories we share" sender="the team at Whynot Productions"
dry=0; attaches=()
while [ $# -gt 0 ]; do
  case "$1" in
    --to) to="${2-}"; shift 2 ;;
    --person) person="${2-}"; shift 2 ;;
    --projects) projects="${2-}"; shift 2 ;;
    --from) sender="${2-}"; shift 2 ;;
    --attach) attaches+=("${2-}"); shift 2 ;;
    --template) TEMPLATE="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'letter: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$to" ] || { printf 'letter: --to is required\n' >&2; exit 2; }
[ -n "$person" ] || { printf 'letter: --person is required\n' >&2; exit 2; }
[ -f "$TEMPLATE" ] || { printf 'letter: no template at %s\n' "$TEMPLATE" >&2; exit 1; }

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
home="${YMIR_HOME:-}"
[ -n "$home" ] || ymir_home_root home 2>/dev/null || true
[ -n "$home" ] || { printf 'letter: no hoard — run bin/engine/ymir-install.sh, or set YMIR_HOME\n' >&2; exit 1; }
outdir="$home/hodd/state/collab/letters"
mkdir -p "$outdir"

first="${person%% *}"
slug="$(printf '%s' "$person" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//')"
out="$outdir/$(date -u +%Y-%m-%d)-$slug.md"

subject="$(sed -n 's/^Subject: //p' "$TEMPLATE" | head -1)"
body="$(sed -e '/^Subject: /d' -e '/./,$!d' \
            -e "s|{{name}}|$first|g" \
            -e "s|{{projects}}|$projects|g" \
            -e "s|{{from_name}}|$sender|g" "$TEMPLATE")"
printf '%s\n' "$body" > "$out"

if [ "$dry" = 1 ]; then
  printf 'collab[4]{field,value}:\n'
  printf '  "to","%s"\n' "$to"
  printf '  "subject","%s"\n' "$subject"
  printf '  "rendered","%s"\n' "$out"
  printf '  "state","dry run — nothing drafted, nothing sent"\n'
  exit 0
fi

[ -x "$MAIL" ] || { printf 'letter: the mail gate is not executable: %s\n' "$MAIL" >&2; exit 1; }
args=(draft --to "$to" --subject "$subject" --body "$out")
for file in "${attaches[@]:-}"; do [ -n "$file" ] && args+=(--attach "$file"); done

answer="$("$MAIL" "${args[@]}")"
printf 'collab[3]{field,value}:\n'
printf '  "to","%s"\n' "$to"
printf '  "rendered","%s"\n' "$out"
printf '  "gate","%s"\n' "$(printf '%s' "$answer" | tr '\n' ' ' | cut -c1-200)"
printf 'approve[1]{step,command}:\n'
printf '  "send","systems/snotra/services/letters/mail-send.sh send <draft-id> — only on the Allfather'"'"'s word"\n'
