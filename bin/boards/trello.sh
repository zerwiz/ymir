#!/usr/bin/env bash
# trello.sh — THE house door to Trello's REST API (plan 324 F1–F4). The verbs and the why live in
# trello.py beside it; `trello.sh --help` prints them. Key and token come from the environment or the
# vault (TRELLO_API_KEY, TRELLO_TOKEN) — never from a file in this repository. Unset is a clean skip
# that names the missing value (RULES/25).
set -uo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/trello.py" "$@"
