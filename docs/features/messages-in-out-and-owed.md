# Your messages, in, out and owed — and the to-do they move

## What it is

One door, `bin/records/comms.sh`, answers four questions about your communications:

- **What came in, and what went out?** Mail and Telegram, per channel, for any span of hours.
- **What do I still owe?** Every letter, draft and approval waiting to be sent, with who it is for and where it sits.
- **What does that change on my list?** It proposes to-do changes, and each proposal carries the message behind it.
- **What did the morning say?** The 07:00 brief carries the same counts and the same proposals.

It never sends, replies to, labels or deletes a message. Mail is read where it already lives. Nothing reaches your
to-do without your yes.

## How it fits together

```mermaid
flowchart LR
    mail[(Mail record<br/>messages.jsonl)] --> door[comms.sh]
    tg[(Telegram record<br/>comms/telegram.jsonl)] --> door
    shelves[Letter and draft shelves<br/>and approvals] --> door
    door -->|proposes, with evidence| you[You say yes]
    you -->|dated line| todo[(todo.md<br/>house-kept half)]
    door --> brief[07:00 brief]
```

## What you need

| Thing | Where | Notes |
|---|---|---|
| Your home | `$YMIR_HOME` | resolved the usual way (`bin/vault/hodd.sh path`) |
| The mail record | `hodd/memory/mail/messages.jsonl` | written by the mail desk's ingest; the door only reads it |
| The Telegram record | `hodd/memory/comms/telegram.jsonl` | appended by the Skírnir bot (both ways) and by the hotline when it sends |
| Your to-do | `hodd/life/personal/me/todo.md` | the door adds a house-kept half at the end; your half is never edited |
| Gmail (optional) | the mailbox grant | read-only search, for your Gmail drafts and a signing platform's reminders |

## Do it

```bash
bin/records/comms.sh summary --hours 24     # per channel: in · out · owed
bin/records/comms.sh list --channel telegram
bin/records/comms.sh owed                    # everything waiting to be sent
bin/records/comms.sh todo-matches            # proposed changes, each with its message
bin/records/comms.sh todo-apply 1a2b3c4d     # write only the ones you said yes to
bin/records/comms.sh brief                   # the morning brief's section
```

By voice, say *"update my to-do from my mail"*. Nanna reads the proposals to you through the `todo_from_mail` hand,
and writes only the ones you approve. The `comms` hand answers *"what did I send?"* and *"what do I still owe?"*.

## How a message proposes a change

| Kind | When | Evidence it shows |
|---|---|---|
| **tick** a *Send / Answer / Ask* item | a mail went out to every person the item names, with the item's own words in the subject | the mail, its address and its date |
| **tick** a *Confirm / Accept* item | the platform said it is done, or its reminders to you stopped, or the person who asked has since written to you from inside that account | the request, and the mail that shows it moved |
| **open** an item under *Today* | an incoming mail the desk marked *reply needed*, with nothing sent to that person since | the mail |
| **wait** under *Waiting on others* | you asked a question and nothing has come back from that person since | your mail |

A *Confirm* or *Accept* is graded **medium** unless the platform says it is completed. Mail cannot see a signature
or an accepted invitation, so the proposal says what it saw and asks you.

> [!IMPORTANT]
> Your own lines are never edited. An approved change is written as a dated line in the house-kept half
> (**Today**, **This week**, **Waiting on others**), ending with the item's id so it is never proposed twice.

## Limits

- The counts are only as fresh as the mail ingest. When its newest row is older than the span, the brief says so.
- Telegram is recorded by the Skírnir bot and the hotline. The pi Telegram bridge does not record yet.
- Meetings, the calendar and Trello are not in the record yet (plan 261, phases C4 and C5).
- The brief reads offline, so it does not list your Gmail drafts. `comms.sh owed` does.

## If it does not work

- **`the home is unresolved`:** set `YMIR_HOME`, or check `bin/vault/hodd.sh path`.
- **No SignWell-style proposal:** the reminder series is read live from Gmail. Run `bin/mail/mail-scan.sh --query
  'in:drafts'` to check that the grant answers.
- **A proposal looks wrong:** do not apply it. The evidence column names the message, so the fault can be traced.
  The proofs are `python3 -m unittest discover -s bin/records/tests -p 'test_comms.py'`.

*Where this sits:* plan 261 · [the mail desk](gna-the-one-mail-desk.md) · [the hotline](the-hotline.md) ·
[your todos](the-allfathers-todos.md).

## CHANGE LOG

- **2026-11-12** — Written, and carried into main by the gathered batch; from here appended, never rewritten.
