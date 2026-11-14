#!/usr/bin/env bash
# gate-verdict.sh — record the verdict for one sha. The store is what merge-verdict.sh reads.
#
#   gate-verdict.sh record <sha> PASS|FAIL "why"
#   gate-verdict.sh show   <sha>
set -uo pipefail
store="${YMIR_HOME:-$HOME/Documents/ymirhome}/hodd/state/gate-verdicts"
mkdir -p "$store"
case "${1:-}" in
  record)
    sha="${2:-}"; verdict="${3:-}"; why="${4:-}"
    [ -z "$sha" ] || [ -z "$verdict" ] && { echo "usage: gate-verdict.sh record <sha> PASS|FAIL \"why\"" >&2; exit 2; }
    printf '%s %s %s %s\n' "$(date -u +%FT%TZ)" "$sha" "$verdict" "$why" >> "$store/verdicts.txt"
    printf 'recorded: %s %s\n' "${sha:0:8}" "$verdict" ;;
  show)
    grep "${2:-}" "$store"/*.txt 2>/dev/null | tail -3 || echo "no verdict for ${2:-}" ;;
  *) sed -n '2,8p' "$0" ;;
esac
