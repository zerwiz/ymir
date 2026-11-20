# Action register

One row per action. The register is the queue; the minutes are the narrative.

| Field | Rule |
|---|---|
| `action_id` | `ACT-YYYYMMDD-NN`, stable for the life of the action |
| `verb` | imperative, one verb: send, draft, file, confirm, schedule |
| `deliverable` | the object produced, not the activity. "Send the capability matrix", not "work on capabilities" |
| `owner` | exactly one named person. "We", "the team", "someone" are not owners |
| `accountable` | who checks it; may differ from the owner |
| `due_at` | ISO date. Null only with `date_unresolved: true` and a `decide_by` |
| `dependency` | another action id, a document, or an external party |
| `definition_of_done` | the observable condition that closes the card |
| `board` / `list` | the Trello destination. Only `Inbox` is written by the agent |
| `evidence` | transcript timestamp + verbatim quote |
| `confidence` | high = owner + date + concrete verb; medium = one missing; low = neither |
| `status` | proposed · accepted · in_progress · blocked · done · dropped |

## Closure rules

- A card moves to `Done` only when `definition_of_done` is met and the evidence
  is attached.
- A blocked action names the blocker and the person who must remove it.
- An action whose date is unresolved cannot be marked done; it must first be
  dated or dropped by the owner.
- Dropping an action is a decision, and is recorded in the decision log.
