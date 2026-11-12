#!/usr/bin/env bash
# maker-guard.sh — the ward over what a commit or a pull request SAYS (RULES/53).
#
# It refuses prose that names a model, a model maker or an agent harness: a client's history
# is the client's record. The matcher is bin/forge/maker-names.py (one list: bin/gates/maker-words.txt,
# exceptions with reasons: bin/gates/maker-allow.txt). Code — a fenced block or a `backticked span` —
# is never judged.
#
#   maker-guard.sh message <file>        a commit message (the commit-msg hook)
#   maker-guard.sh push                  stdin: pre-push ref lines; every NEW commit message in the range
#   maker-guard.sh range <base> <head>   every commit message in base..head (a client repo's pre-push)
#   maker-guard.sh text <label> <file>   any text: a PR title, a PR body, a status line
set -u
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# in the repo the matcher is bin/forge/maker-names.py; in a client repo the kit ships it beside this ward
MATCH="$HERE/../../forge/maker-names.py"; [ -r "$MATCH" ] || MATCH="$HERE/maker-names.py"
[ -r "$MATCH" ] || { echo "maker-guard: no matcher; skipping" >&2; exit 0; }
Z=0000000000000000000000000000000000000000

refuse() { # <label> <hits>
  printf 'refused: %s names a model, a maker or an agent harness (RULES/53):\n' "$1" >&2
  printf '%s\n' "$2" | sed 's/^/  /' >&2
  printf 'help: say "the agent harness" or "the worker"; put a path, flag or id in `backticks`; or add a reasoned line to bin/gates/maker-allow.txt\n' >&2
}

case "${1-}" in
  message)
    hits="$(python3 "$MATCH" scan "$2" --git-message)" && exit 0
    refuse "this commit message" "$hits"; exit 1 ;;
  text)
    hits="$(python3 "$MATCH" scan "$3")" && exit 0
    refuse "$2" "$hits"; exit 1 ;;
  range)
    rc=0
    for c in $(git rev-list --no-merges "$2..$3" 2>/dev/null); do
      t="$(mktemp)"; git log -1 --format=%B "$c" >"$t"
      if ! hits="$(python3 "$MATCH" scan "$t")"; then refuse "commit ${c:0:9}" "$hits"; rc=1; fi
      rm -f "$t"
    done
    exit $rc ;;
  push)
    rc=0
    while read -r _lref lsha _rref rsha; do
      [ -n "${lsha:-}" ] && [ "$lsha" != "$Z" ] || continue
      if [ "$rsha" = "$Z" ]; then
        if git rev-parse -q --verify origin/main >/dev/null 2>&1; then range="$lsha --not origin/main"; else range="$lsha --not --remotes"; fi
      else range="$rsha..$lsha"; fi
      # shellcheck disable=SC2086
      for c in $(git rev-list --no-merges $range 2>/dev/null); do
        t="$(mktemp)"; git log -1 --format=%B "$c" >"$t"
        if ! hits="$(python3 "$MATCH" scan "$t")"; then refuse "commit ${c:0:9}" "$hits"; rc=1; fi
        rm -f "$t"
      done
    done
    exit $rc ;;
  *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
