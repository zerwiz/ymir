#!/usr/bin/env bash
# gate-verdict.sh — record the verdict for one sha. The store is what merge-verdict.sh reads.
#
#   gate-verdict.sh record <sha> PASS|FAIL "why"
#   gate-verdict.sh show   <sha>
set -uo pipefail
# the ONE resolver says where the home is (Rule 07); a home it cannot name is a refusal, not a guess
_h="${YMIR_HOME:-}"
if [ -z "$_h" ]; then
  . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../vault/hoard-lib.sh" 2>/dev/null || true
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root _h 2>/dev/null
fi
[ -n "$_h" ] || { printf '%s: no Ymir home resolves (bin/vault/hoard-lib.sh)\n' "$(basename "$0")" >&2; exit 2; }
store="$_h/hodd/state/gate-verdicts"
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
