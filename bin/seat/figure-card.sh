#!/usr/bin/env bash
# figure-card.sh — print a figure's card, front matter stripped, for a seat's opening turn.
#
#   bin/seat/figure-card.sh <role-or-figure>     judge -> forseti, coder -> sindri, scout -> kvasir, helm -> brokk
#
# Every seat on every harness opens with its figure's card (src/ymir_runtime/figure_card.py is the
# one rule; the engine road and this door both call it). Prints nothing for a figure with no card.
set -u
case "${1-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
SELF="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
TREE="$(dirname "$(dirname "$SELF")")"
PYTHONPATH="$TREE/src${PYTHONPATH:+:$PYTHONPATH}" exec python3 "$TREE/src/ymir_runtime/figure_card.py" card "$TREE" "$1"
