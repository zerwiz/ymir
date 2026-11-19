#!/usr/bin/env bash
# voices.sh — the door to every Kokoro voice on this machine (plan 326.1–326.5).
#
#   voices.sh list [--json]                   every voice: id, name, language, gender, lang code
#   voices.sh resolve <name|id>               one id — `eric` -> `am_eric`; an ambiguous name is refused
#   voices.sh catalogue                       the YAML catalogue on stdout
#   voices.sh catalogue --home                written to the hoard's identity/voices.yaml (resolved, never guessed)
#   voices.sh catalogue --write <path>        written to <path>
#   voices.sh say <name|id> [text] [--to f]   a sample in that voice; --to writes a file and plays nothing
#
# The list comes from the engine (`kokoro voices --json`, which reads voices-v1.0.bin), never from a table
# kept here. `say` without --to plays sound, so it refuses while the desk is held (bin/desk/in-call.sh).
# The engine takes the voice with every request; its configured voice is a default, never the only one.
#
# Exit: 0 ok · 1 the engine could not answer · 2 usage · 3 unknown or ambiguous name · 4 the desk is held.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
if [ "${1:-}" = "catalogue" ] && [ "${2:-}" = "--home" ]; then
  # shellcheck source=../vault/hoard-lib.sh
  . "$SCRIPT_DIR/../vault/hoard-lib.sh"
  hoard_root HOARD
  exec python3 "$SCRIPT_DIR/voices.py" catalogue --write "$HOARD/identity/voices.yaml"
fi
exec python3 "$SCRIPT_DIR/voices.py" "$@"
