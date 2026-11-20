#!/usr/bin/env bash
# library.sh — the library of records: one corpus, one contract, one door (plan 115).
#
# The house had registers and no corpus: a document was a loose `.md` with no shape, no
# status, and nothing that could say whether it was still true — and what an agent LOOKED UP
# was kept nowhere at all. This is the one door over both halves.
#
#   library.sh check [--changed]      coverage per shelf; --changed gates only the diff
#   library.sh ask <words…>           one query across doors, capabilities, features, law, skills, research
#   library.sh index                  the library's own view, in the home
#   library.sh research keep|list|show|find|index|check …
#   library.sh self-test              10 assertions, in a temp root — never the real library
#
# The contract is the one `.pi/extensions/ymirhome.ts` already ships, extended with `tags` and
# `sources`: kind · status · verified · verified_by · supersedes · superseded_by · grade ·
# aliases · canonical · origin · used_by · sensitivity · owner · tags · sources.
# Law: RULES/34-the-record-has-a-shape.md · RULES/35-the-research-is-kept.md.
#
# Roots (Rule 07): the repo from the marker walk; the home from bin/vault/hoard-lib.sh.
#
# Exit: 0 clean · 1 findings · 2 usage.
set -uo pipefail

VERSION="1.0.0"

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}
ROOT="$(_root)"

case "${1-}" in
  -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1-}" ] && exit 0 || exit 2 ;;
  self-test) exec python3 "$ROOT/src/ymir_runtime/library.py" self-test ;;
esac

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$ROOT/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR; fi

case "${1-}" in
  check) shift
         if printf '%s\n' "$@" | grep -qx -- '--changed'; then
           exec python3 "$ROOT/src/ymir_runtime/library.py" check --repo "$ROOT" --home "${HOME_DIR:-}" --changed "$@"
         fi
         exec python3 "$ROOT/src/ymir_runtime/library.py" check --repo "$ROOT" --home "${HOME_DIR:-}" "$@" ;;
  ask)   shift; exec python3 "$ROOT/src/ymir_runtime/library.py" ask --repo "$ROOT" --home "${HOME_DIR:-}" "$@" ;;
  index) shift; exec python3 "$ROOT/src/ymir_runtime/library.py" index --home "${HOME_DIR:-}" "$@" ;;
  research) shift
         R="${YMIR_RESEARCH_ROOT:-${HOME_DIR:+$HOME_DIR/hodd/library/research}}"
         if [ -z "$R" ]; then
           printf 'library: cannot resolve the research shelf — set YMIR_RESEARCH_ROOT or seat the home (bin/vault/hoard-lib.sh)\n' >&2
           exit 2
         fi
         exec python3 "$ROOT/src/ymir_runtime/library.py" research --root "$R" "$@" ;;
  *) printf 'error: unknown command %s\nhelp: library.sh check|ask|index|research|self-test\n' "$1" >&2; exit 2 ;;
esac
