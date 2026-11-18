#!/usr/bin/env bash
# public-guard.sh — the OLDER door to RULES/04's judgement: templates and logic, nothing private.
#
# SUPERSEDED, NOT REMOVED (Rule 11). `public-guard.py` is the ward — it reads the operator's own
# words from his home, judges topology by shape, and prints its scope on every run. This file stays
# because a rule, a skill and the pre-commit habit all name it, so the two would otherwise answer
# differently: it was a second implementation of the same rule, and the second one carried the
# operator's real mail domain in its own allow-list — the leak the ward exists to refuse (RULES/04).
#
# So the door is kept and the judgement is NOT restated: every flag maps onto public-guard.py.
#
#   public-guard.sh            # inspect the staged change (same as `public-guard.py --staged`)
#   public-guard.sh --all      # inspect every tracked file (`public-guard.py --tree`)
#   public-guard.sh --tree     # the same, under the younger spelling
#   public-guard.sh --staged   # the staged change
#   public-guard.sh --list     # the classes and what each allows
#
# Exit: 0 clean · 1 findings · 2 usage (whatever public-guard.py answers).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARD="$HERE/public-guard.py"
[ -r "$WARD" ] || { printf 'public-guard: %s is missing\n' "$WARD" >&2; exit 2; }

args=()
for a in "$@"; do
  case "$a" in
    --all|--tree) args+=(--tree) ;;
    "")           ;;
    *)            args+=("$a") ;;
  esac
done
[ "${#args[@]}" -gt 0 ] || args=(--staged)
exec python3 "$WARD" "${args[@]}"
