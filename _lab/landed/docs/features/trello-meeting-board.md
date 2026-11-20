# The Trello meeting board

**What it is.** Every meeting record — its decisions, actions, open questions and
sign-off — as cards on one Trello board, generated from the record.

**What you need.** A Trello account with the board shared to you, and the Trello MCP
grant connected on this machine (`mcp({ connect: "trello" })`).

## Use it

```sh
# create or update every card for a meeting; safe to run again
systems/snotra/services/cron/snotra-trello.sh export "$YMIR_HOME/svartalfaheim/synteon/meetings/2026-10-20-roadmap"

# move the sign-off card when confirmations arrive
systems/snotra/services/cron/snotra-trello.sh sync "$YMIR_HOME/svartalfaheim/synteon/meetings/2026-10-20-roadmap"

# what is on the board, per list
systems/snotra/services/cron/snotra-trello.sh doctor "$YMIR_HOME/svartalfaheim/synteon/meetings/2026-10-20-roadmap"
```

The board URL is written into `trello.json` beside the record and into the follow-up
letter.

## What a card carries

- **Name** — the human title first, then the id and the meeting: `Provisional patent while
  validating — DEC-… · Road map & Trello · 2026-10-20`.
- **Description** — the decision (Approver, grade, rationale, reversibility, review date,
  evidence) or the action (owner, due, done-when, dependency, source).
- **Label** — `Grade A/B/C`, `Blocking`, `Question`.
- **Due date** — review date, action due, question needed-by, sign-off window.
- **Checklist** — `Decision checks`, `Done when`, `Resolution`, `Meeting checks`,
  `Sign-off`.
- **Member** — the person responsible, as a real Trello member.
- **Workstream copy** — a subject card is copied once to Patent, Vertical Comparison or
  Documentation, with a source link.

## Lists are states

`Meetings · Agenda · Proposed · Decided · Actions · Blocked · Done · Open Questions ·
Sign-off · Signed`. Move a card when its state changes; do not create a list per meeting.

## Limits

- A copy is not a live mirror: work on the workstream copy, the meeting card stays the
  record.
- Inbox is personal capture, not a board list.
- Google Chat is one-way: Trello alerts Chat; Trello cannot read the room.
- The sign-off parser reads replies with `snotra-signoff.sh sync`; a live reply has not
  yet been exercised.

The full design, the research and the audit are in
`$YMIR_HOME/svartalfaheim/synteon/framework/trello-workflow.md`.
