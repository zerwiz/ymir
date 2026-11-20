# Trello automation — what Butler can do for us, and what it may never do

Audited 2026-10-23 from Atlassian's own documentation (Butler automation, webhooks, email reports). This page maps
what Trello can automate onto the things this house actually needs, and draws the line the meeting's decisions
already drew: **the board is a projection, the record is the truth.**

## What Trello's automation actually offers

```
types[5]{type,trigger,example}:
  "Rule","something happens on the board (by anyone, not just you)","when a card is moved into Done → complete its checklist"
  "Scheduled","a time or a cadence","every Monday 08:00 → create a card in Agenda"
  "Due date","relative to a card's due date","1 day before due → add the label 'Due soon' and comment on the card"
  "Card button","a click on one card","'send to the client' → move to Sign-off and post the record link"
  "Board button","a click across the board","'weekly sweep' → archive every card in Done older than a week"
```

```
actions[6]{what it can do,usable for us}:
  "move · archive · copy · sort cards","yes — list hygiene, and DEC-07's layering (a Done card can seed the next one)"
  "labels · members · due dates · checklists","yes — the nudges: a grade label, an owner, a due date, a done-checklist"
  "rename · description · comment","**partly** — Butler may comment on a card, but it may never rewrite the record"
  "custom fields","yes, if a place declares them; the record remains the source"
  "send email · email reports (up to 100 cards)","**NO for partners** — it bypasses `snotra-approve.sh`, the gate that exists because a letter reached partners unread on 2026-10-23"
  "HTTP request (Content)","yes — but only to our own door, with a shared secret; a board that can POST anywhere is a board that can leak"
```

```
webhooks[2]{fact,consequence}:
  "Trello webhooks are API-only, belong to a token, and fire on model changes (`updateCard`, `commentCard`, `moveCardToBoard`, …)","this is DEC-06's real answer: 'moving a card can trigger actions' needs a receiver, not a Power-Up"
  "they do not fire for objects the token cannot see","the grant must be the same one the projector uses, or a move is invisible"
```

## The mapping — every need we have, against what can fulfil it

| need (from the record) | Butler can | the house must | verdict |
|---|---|---|---|
| **DEC-06** — moving a card can trigger actions | Rule → mark checklist complete, label, comment | receive the webhook and act on the **record** (promote, correct, notify) | **Butler for the board's hygiene; a webhook receiver for the record** |
| **DEC-07** — layers: a Done card on the company board seeds a feature board | Rule → create a card from a template on the workstream board | keep the idempotency key (`record-key`) so the copy is not a twin | **Butler can seed; the door must still verify** |
| **DEC-04** — the agenda, sent 1–2 days ahead | Scheduled → create an Agenda card weekly | write the card from the record (proposed → due → open questions) and file it | **`snotra-agenda.sh` already does it; Butler is the fallback if the door does not run** |
| **DEC-10** — the record out 15 minutes after the meeting | Due date command → remind the chair | render, approve, send | **Butler may remind; only the approval gate may send** |
| the letters' confirmation by a date | Due date command → comment on the card a day before | read the reply, record it, promote on a person's word | **Butler nudges the owner; `snotra-mail-watch` reads the answer** |
| a decision waiting too long | Scheduled → weekly email report of `Decisions` | nothing — the report is internal | **usable, to the operator's own address only** |
| knowing a card was moved by a human | Rule → comment "moved by …" | treat it as drift and leave it (`project verify` reports it) | **Butler's comment is the audit trail the door cannot see** |

## The commands, ready to paste (Synteon's Documentation board)

Butler's own language, four rules and one scheduled command. Nothing here touches the record, and nothing sends
mail to a partner.

```
when a card is added to list "Decisions" by anyone, set due in 3 days, and add the blue "Plan" label
when a card is moved into list "Done" by anyone, mark all the items in checklist "Definition of done" as complete
when a card is moved into list "Done" by anyone, set due date to complete, and add comment "closed by {username}"
every monday at 08:00, create a card in list "Next Meeting Agenda" named "Weekly review — {week}" and add the checklist "Agenda"
every day at 09:00, for each card in list "Decisions" with no due date, set due in 3 days
```

**Two commands that must NOT be created on a client board:**

```
✗ when a card is moved into "Sign-off", send email to {client} …      ← bypasses the approval gate
✗ every friday, send email report to {client} …                      ← same, and it is unapproved prose
```

## What this means for the build

1. **Butler is for the board's own hygiene** — lapping, labels, due-date nudges, checklist completion, seeding a
   workstream card, and a comment trail of who moved what. It is genuinely useful and costs nothing.
2. **The record is untouched by it.** Butler cannot promote a decision, cannot correct a record, and must never
   send a partner a letter. Those are `snotra-promote.sh`, `snotra-letter.sh` + `snotra-approve.sh`.
3. **The event bus is a webhook receiver, not a Power-Up.** DEC-06 becomes real the day we run a door that accepts
   Trello's `updateCard`/`moveCardToBoard` callbacks with a shared secret, matches the `record-key`, and records
   the event — with the board action treated as a *proposal*, exactly as a reply is evidence and not a signature.
4. **One rule per board, declared in the place profile** (next step): a `board.automations:` block listing the
   Butler commands a place expects, so "the board's rules" are part of the place's shape and a second company can
   declare its own — the same law that keeps company names out of the code.

## Still to build (named, not implied)

- `snotra-trello-webhook.sh` — a receiver with a shared secret, `record-key` matching, and a rune per event.
- `board.automations:` in the place contract, so the five commands above are declared rather than remembered.
- A check in `smoke.sh` that a board whose place declares automations actually has them (Trello exposes them only
  through Butler's UI, so this check would have to read the board's `prefs` or ask the operator — until then the
  list is a document, not a gate, and it says so).
