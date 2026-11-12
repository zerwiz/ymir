#!/usr/bin/env bash
# model-allow.sh — may an Eindri run on this model? The ONE door to the allow-list.
#
#   bin/model/model-allow.sh check <provider/model> [--harness h] [--for <task-id>]
#   bin/model/model-allow.sh check opus --harness claude     # aliases resolve to an allowed id
#   bin/model/model-allow.sh default <harness>               # the list's default model, plain
#   bin/model/model-allow.sh list                            # the list, its defaults, its grants
#   bin/model/model-allow.sh audit [<state-dir> …]           # live seats on a refused model
#   bin/model/model-allow.sh path                            # where this operator's list lives
#
# The list is the operator's own setting in the home (`<home>/config/models-allowed.yaml`;
# template config/models-allowed.yaml.example) — never a list in this tree (RULES/04, 07).
# A model not on it is refused unless a dated, named grant in the same file allows it.
# No environment variable allows a model. `--for <id>` writes grant uses and refusals to
# `<state>/model-allow.log`.
#
# Exit: 0 allowed (or unpoliced: no list written) · 1 fault · 2 usage · 3 refused.
# The rule lives in src/ymir_runtime/allow.py; this door only hands it the words.
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
SELF_DIR="${BASH_SOURCE[0]%/*}"
[ "$SELF_DIR" = "${BASH_SOURCE[0]}" ] && SELF_DIR=.
CORE="$SELF_DIR/../../src/ymir_runtime/allow.py"
[ -r "$CORE" ] || { printf 'error: the allow-list core is missing at %s\n' "$CORE" >&2; exit 1; }
exec python3 "$CORE" "$@"
