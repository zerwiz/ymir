# Trello mapping

Trello is the queue. The agent writes **only** into `Inbox`; a human moves a card
into a stage, because stages differ by workstream.

| Workstream | Board | Stages |
|---|---|---|
| Contracts and company documents | Documents | To produce → Drafting → In review → Signed |
| Patent and IP | Patent | Phase 1 → Phase 2 → Phase 3 → Filed |
| Application and product | Application | Backlog → In progress → Blocked → Done |
| Vertical exploration | Vertical comparison | Gate 0 → Gate 1 → Gate 2 → Gate 3 (pilot) |
| Anything else | Inbox | Inbox → Done |

## Card shape

```
Title:      <verb> <deliverable>
Description:
  Source: <meeting title> — <date> — <timestamp>
  Decision: <decision_id or "none">
  Definition of done: <observable condition>
  Dependency: <action id | document | external party>
  Evidence: "<verbatim quote>"
  Action ID: <ACT-...>
Members:    the single owner
Due:        ISO date
```

## Rules

- One action per card. A card with two owners is two cards.
- No card without a due date may leave `Inbox`; `date unresolved` cards carry a
  `decide_by` date and are reviewed weekly.
- The card description carries the evidence, because the card will outlive the
  meeting file.
- Board names are read from the record; when a board does not exist, the card
  goes to `Inbox` and the mismatch is reported, never guessed.
