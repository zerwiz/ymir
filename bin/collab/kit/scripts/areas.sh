#!/usr/bin/env bash
# areas.sh — this repository's own answer to the canon of areas (a thin door; the craft is areas.py).
#
#   bash scripts/areas.sh init            # one file per canon area, every one honestly `unheld`
#   bash scripts/areas.sh list            # area · state · keeper · open questions
#   bash scripts/areas.sh check           # names what is unanswered or unproved; exit 1 on a fault
#   bash scripts/areas.sh check --strict  # also refuses an area that is merely `unheld`
#   bash scripts/areas.sh estate          # the one line the baton carries
#   bash scripts/areas.sh canon           # the eighteen ids and their questions
#   bash scripts/areas.sh claim <area> --keeper "…" --path "…" --evidence "…" [--lens "…"]
#   bash scripts/areas.sh waive <area> --by "…" --why "…" --until YYYY-MM-DD
#
# A skip is a pass; a silent green is a lie. If this repository has never run `init`, `check` says so
# and names the command rather than pretending the estate is empty and clean.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/areas.py" "$@"
