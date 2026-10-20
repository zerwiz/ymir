## snotra · unversioned · 2026-10-20 — Trello is a projection of the record

### What

- `snotra-trello.sh` / `snotra-trello.py` — production export: idempotent by record id,
  automatic OAuth refresh, board and ten lists, grade/state labels, real members from the
  workspace, due dates, checklists, human card names with the meeting tag, and one
  workstream copy to Patent / Vertical Comparison / Documentation.
- `sync` moves the sign-off card from `signoffs.json`; `doctor` reports the board.
- The first runs matched names only at the start, created a new card each run, and left
  114 cards with 3–4 copies. Matching is now anywhere in the name; the duplicates were
  deleted and the board is 36 cards with no duplicates.
- Sign-off `sync` is wired into the shell case and returns `no replies found` cleanly.

### Verified

- Export: 36 cards — 1 meeting, 10 decisions, 16 actions, 8 questions, 1 sign-off.
- All four participants are board members; owned cards carry `idMembers`.
- Due dates: decisions by review date, actions by due, questions by needed-by, sign-off
  two business days after the meeting.
- Labels created through REST (`Grade A/B/C`, `Blocking`, `Question`); MCP cannot create
  labels.
- Board: <https://trello.com/b/5eh3eaGl/synteon-meetings>.

### Not verified

- A live sign-off reply; the parser has only run against a clean inbox.
- Planner events: documented, not created.
- Copies are copies, not live mirrors.
