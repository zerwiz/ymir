#!/usr/bin/env bash
# a2a.sh — this repository's card in the constellation (a thin door; the craft is a2a.py).
#
#   bash scripts/a2a.sh card            # what the card would say, from areas/ — printed, nothing written
#   bash scripts/a2a.sh card --write    # write .well-known/agent-card.json
#   bash scripts/a2a.sh card --url https://…/ --write   # publish the address that actually answers
#   bash scripts/a2a.sh check           # validate it: protocol, name, url, a skill per HELD area, no secrets
#   bash scripts/a2a.sh skills          # what this repository answers for, and who holds it
#
# The card is generated from `areas/` — the same shelf `scripts/areas.sh` writes and the gate reads.
# A held area becomes a skill; an unheld area is NOT offered: you do not advertise work nobody holds.
#
# The card is an invitation to ASK. It is never a grant: a peer still needs a per-pair, per-skill grant
# with an expiry, and every call is recorded. Ports, hosts and paths of the house never appear here.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/a2a.py" "$@"
