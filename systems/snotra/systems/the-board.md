# The board — a projection of the record, made once per place

`services/cron/snotra-board.sh` makes the board, `services/cron/snotra-project.sh` fills it, and
`services/cron/snotra-trello.sh` is the transport. The board is a **projection**: the record is the truth, the cards
are what the record says today, and a card edited by hand in the board is overwritten by the next projection.

## The laws

- **A place declares its board.** The board and its lists are named in the place's profile; until the board exists
  the first projection fails. So `check` says whether it is there, and `ensure` creates only what is missing.
- **A name that exists is never created again** (in the map, `trello-map.yaml`). This is measured, not cautious: on
  2026-10-22 a second "Control Tower" board was created by hand.
- **A list that exists is never renamed.** A profile that renames a list silently files cards nowhere.
- **The board is created private**, in the organisation the other boards already belong to.
- **`ensure` prints what it created and what it left alone**, and re-reads the board to prove it.

## The doors

```
snotra-board.sh show                 the places this home declares
snotra-board.sh check <place>        is the board there, with the lists and labels the place names?
snotra-board.sh ensure <place>       create what is missing — never a duplicate, never a rename
snotra-project.sh plan <meeting-dir> what would be projected, by kind, verified
snotra-project.sh apply <meeting-dir>
snotra-trello.sh export <meeting-dir>  the idempotent transport
trello-due.sh                        the digest of overdue promises
```

Where a domain's board is the *agent-control* board of plan 129 (`board: snotra/projects`), this is the same door:
one board per place, its queue, its blocked items, its decisions — and the meeting's cards are projected into it.
