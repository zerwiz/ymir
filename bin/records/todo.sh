#!/usr/bin/env bash
# todo.sh — the operator's to-do, as cards on the board. The ONE door the house writes it through.
#
#   todo.sh add "<what>" [--lane Inbox|Today|"This week"|Waiting|Someday|Done] [--due YYYY-MM-DD]
#                        [--owner WHO] [--priority P] [--source S] [--note TEXT] [--key K] [--json]
#   todo.sh list [--lane L] [--json]
#   todo.sh move <card> <lane>
#   todo.sh flush | lanes | status
#   todo.sh migrate [--dry-run] [--json]
#
# The logic lives in bin/records/todo_board.py (read its head). Unconfigured is a clean skip (exit 0).
set -u
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/todo_board.py" "$@"
