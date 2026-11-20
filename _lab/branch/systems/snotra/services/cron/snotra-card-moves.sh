#!/usr/bin/env bash
# snotra-card-moves.sh — card-movement automation rules (DEC-20261022-04).
#
#   snotra-card-moves.sh watch   <board-name> [<meeting-dir>]   scan for Rule A / Rule B
#   snotra-card-moves.sh dry-run <board-name> [<meeting-dir>]   what would happen
#   snotra-card-moves.sh status  <board-name>   one row per card in This Week / Done
#
# Rule A: moved to This Week with a member → assign + notify + suggested steps.
# Rule B: done + sign-off needed → To Sign-off; mis-move to Done → move back + note.
# Note-on-mis-move: every automated correction leaves a comment on the card.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
exec python3 "$ROOT/bin/time/snotra/snotra-card-moves.py" "$@"
