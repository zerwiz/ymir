#!/usr/bin/env bash
# 0012-places-shelf — give an existing home the PLACES shelf, so a board can be declared before it is made.
#
# Before this migration a place profile existed only on the seat where it was written by hand: a fresh install had
# no `hodd/identity/places/`, so `snotra-project.sh` could only ever answer "no place profile" — correctly, and
# uselessly. This migration creates the shelf and ONE declared example (a house-default `example/projects`), and
# nothing else: it never invents a company, a board id, a decision or a member.
#
# Idempotent: it skips anything that exists, and it never edits a profile it finds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { echo "0012: the hoard is unresolved — nothing touched"; exit 0; }
SHELF="$HOME_R/hodd/identity/places"
mkdir -p "$SHELF"
made=0
if [ ! -d "$SHELF/example/projects" ]; then
  mkdir -p "$SHELF/example/projects"
  cat > "$SHELF/example/projects/place.yaml" <<'YAML'
# A DECLARED PLACE — copy this folder to <company>/<place>/ and change the names.
#
# A place is one company's working surface: the board, the lists things are filed into, the labels that mean
# something, the cadence, the roles, and how long its sound may live. The doors read this file; no company name,
# board name or list name lives in any script. `authority:` cites where the shape came from — a meeting decision,
# a document, or (as here) "house default", which is allowed but must be said.
version: 1
place: example/projects
company: example
surface: trello                 # trello | gimle | jira — a door that does not speak it refuses
board: Example                  # resolved by NAME through hodd/identity/trello-map.yaml
inherits: house-default

authority:
  decisions: []
  note: "house default — this folder is a template, not a company"

lists:
  decision: "Decisions"
  action:   "Doing"
  question: "Open Questions"
  agenda:   "Agenda"

labels:
  "Grade A": red
  "Grade B": orange
  "Grade C": green

meeting_card:
  board: Example
  list: "Agenda"

roles:
  chair: ""                     # who sends the agenda 1–2 days ahead and holds the register
  operator: ""                  # whose mailbox the letters leave from

cadence:
  agenda_lead_days: 2
  signoff_business_days: 2
  monday_at: "09:00"
  record_within_minutes: 15

retention:
  audio_days: 24
  compression: "opus-16k-mono"
  cold_shelf: "external-drive"

never:
  - "a computer microphone is never the record (Rule 33)"
  - "no email is sent without the operator's approval"
  - "a card a human moved is never moved back by a projection"
YAML
  made=1
fi
# the board map and the list names: created empty (never fabricated) so the resolver can answer
[ -f "$HOME_R/hodd/identity/trello-map.yaml" ] || printf 'version: 1\nboards: []\n' > "$HOME_R/hodd/identity/trello-map.yaml"
echo "0012: places shelf ready at $SHELF (example made=$made)"
