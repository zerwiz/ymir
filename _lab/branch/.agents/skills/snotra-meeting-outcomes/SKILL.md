---
name: snotra-meeting-outcomes
description: >-
  Turn a meeting recording or transcript into an accountable record: minutes,
  decisions with rationale, actions with one owner and one due date, per-person
  briefs, a follow-up email, and Trello card payloads. Use whenever a meeting has
  happened and its outcomes must be captured, dispatched, or tracked — or when
  asked for meeting minutes, action items, decisions, owners, a recap email, or
  "what did we agree". Composes Read AI (source), Snotra (capture), and Trello
  (queue). Keywords — meeting, minutes, transcript, recap, action items,
  decisions, owners, follow-up, Trello, Read AI, Fathom, standup, workshop.
argument-hint: "[pipeline | parse | extract | validate | render | cards] <transcript>"
---

# snotra-meeting-outcomes — the record, not the summary

Snotra is the meeting **ear**. This skill is the meeting **record**: the layer
that turns what was heard into what the company is now accountable for.

Read AI, Fathom, Teams, Meet and Snotra all produce transcripts. None of them
produces a defensible record. That is the gap this skill closes, and it closes it
with four rules:

1. **Evidence or silence.** Every decision and action carries a timestamp and a
   verbatim quote, or it is marked unverified and withheld.
2. **One owner, one date.** "We", "the team", and "someone" are not owners. A
   date that was not stated becomes `date unresolved` with a `decide_by`.
3. **The model may return nothing.** A null owner is acceptable; an invented one
   is not. The deterministic extractor is the baseline; a model pass is optional
   and never the authority.
4. **The board is the queue.** Every action becomes a Trello card in `Inbox`.
   Nothing is tracked in a document nobody opens.

## When to use it

| Trigger | Do |
|---|---|
| A meeting ended and a recording or transcript exists | Run the pipeline, then review |
| Asked "what did we decide?" | Read the decision log; quote the evidence |
| Asked "who owes what?" | Read the action register, grouped by owner |
| A participant disputes an item | Append a correction; never rewrite the record |
| Several recorders captured the same meeting | Name the authoritative transcript before extracting |

**Do not use it** to summarise a meeting that produced no decisions and no
actions. Write a one-paragraph note instead; a register of nothing is noise.

## Commands

The engine is one deterministic script. It needs Python 3 and nothing else.

```sh
SCRIPT=.agents/skills/snotra-meeting-outcomes/scripts/meeting-outcomes.py

# one run: parse -> extract -> merge -> validate -> render -> cards
python3 "$SCRIPT" pipeline <transcript.docx|txt|json> \
  --date YYYY-MM-DD --review review.json --outdir <outdir>

# the individual doors
python3 "$SCRIPT" parse    <transcript> --out segments.json
python3 "$SCRIPT" extract  segments.json --date YYYY-MM-DD --out candidates.json
python3 "$SCRIPT" merge    candidates.json --review review.json --date YYYY-MM-DD --out record.json
python3 "$SCRIPT" validate record.json
python3 "$SCRIPT" render   record.json --outdir <outdir>
python3 "$SCRIPT" cards    record.json --out cards.json
```

Exit codes: `0` ok, `1` validation or IO error, `2` usage.

### What a run writes

```
segments.json      parsed transcript: speaker, timestamp, text
candidates.json    machine proposals (never the record)
record.json        the merged, validated record
minutes.md         the document a non-attendee can act from
decisions.md       append-only decision log
actions.md         the register
briefs/<person>.md one per owner, their own actions only
followup-email.md  ready to send, after review
cards.json         Trello payloads: board, list, title, evidence, due, owner
```

## Procedure

### 1. Name the source

If several recorders ran, choose one transcript as authoritative and record the
others in `sources`. Disagreements between transcripts are a finding, not a
detail to smooth over.

### 2. Parse and extract

```sh
python3 "$SCRIPT" pipeline transcript.docx --date 2026-10-20 \
  --review review.json --outdir meetings/2026-10-20-topic
```

The extractor is deliberately conservative. It will surface fewer items than a
language model and it will not invent an owner. Expect the candidate set to be
noisy on a machine transcript: the review is where precision is won.

### 3. Review — the secretary's fifteen minutes

Write `review.json` with the meeting metadata, participants, agenda, and every
decision and action you accept. Curated entries win over machine candidates by
`action_id`/`decision_id`. For each entry:

- copy the quote exactly, with its timestamp;
- name one owner, or leave it out and record the risk;
- date it from the words in the room, or mark it unresolved with a `decide_by`;
- write the `definition_of_done` as an observable condition.

Do not include machine candidates you have not read. `--include-machine` exists
for experiments, not for production.

### 4. Validate

```sh
python3 "$SCRIPT" validate record.json
```

A non-zero exit is a stop. Fix the record; never hand-edit a rendered document,
because the next run will overwrite it.

### 5. Render and dispatch

```sh
python3 "$SCRIPT" render record.json --outdir meetings/2026-10-20-topic
```

Then, in order:

1. Send the follow-up email and the per-person briefs — same day.
2. Create Trello cards from `cards.json`, into `Inbox` only.
3. Append the audit entry.
4. File the record in the vault. Never in the repository.

### 6. Close the loop

At the next meeting, open from the register: overdue items first, then blockers,
then new work. A meeting that does not read the previous register is a meeting
that has already forgotten it.

## Naming the roles

- **Meeting Secretary** — one named person per meeting, on rotation. They own
  `review.json` and the dispatch. The agent assists; it does not own the record.
- **Owner** — one person per action, named in the transcript.
- **Accountable** — who checks it; may differ from the owner, always recorded.
- **Decider** — one person per open question, with a date.

## Stop conditions

Refuse to produce or dispatch when:

- a decision has no quote, or the quote does not support the statement;
- an owner is inferred from a job title rather than named;
- a due date was invented from "soon", "as discussed", or "next time";
- validation returns errors;
- the meeting is `restricted` (patent strategy, contract negotiation, investor
  terms, client vault data) and the transcript would leave the local machine.

## Privacy and scope

Meeting content is private data. Transcripts, recordings, names, quotes and
records live in the vault (`$YMIR_HOME`), never in this repository. The skill,
schema, templates and prompts are public; the content never is.

A `restricted` meeting is processed locally or not at all. The company's
product-side rule — no MCP connection into a client vault — is not weakened by
this internal tooling; the two are separate scopes.

## Limits — say these plainly

- **Speaker labels are only as good as the recorder.** The transcript names who
  spoke; it does not prove they were right. A name-correction calibration against
  previously corrected minutes is part of the procedure, not an optional polish.
- **Relative dates are resolved against the meeting date**, and the resolution is
  recorded (`due_phrase`). Ambiguity is flagged, never hidden.
- **The deterministic extractor has modest recall on messy speech.** That is a
  design choice: a missed item is visible in review, an invented one is not.
- **The card payload is not a Trello write.** It is the exact shape to send; the
  MCP call is a separate, authorised step.
- **Read AI / Gmail / Drive ingestion needs an OAuth grant.** Without it, load a
  transcript file; the pipeline is transport-agnostic.

## Tests

```sh
python3 .agents/skills/snotra-meeting-outcomes/tests/test_meeting_outcomes.py
```

21 tests cover parsing, date resolution, owner inference, evidence, the five
validation gates, rendering, card shape, and curated-over-machine precedence.

## Assets

| Asset | Use |
|---|---|
| `meeting-schema.json` | the contract every record must satisfy |
| `extraction-prompt.md` | optional model pass; strict, null-first |
| `validation-prompt.md` | adversarial second pass, omissions and inventions |
| `minutes-template.md` | the document shape and its rules |
| `action-register.md` | fields, closure rules, board mapping |
| `decision-log.md` | append-only decision entries |
| `participant-brief.md` | the per-person message |
| `followup-email.md` | the receipt, not the retelling |
| `quality-gates.md` | the eight gates and the fail behaviour |
| `trello-mapping.md` | boards, stages, and card shape |

## Snotra's other doors (the ear, not just the record)

Snotra is more than the record. Before asserting she can't do something, check
these doors — the shelves are `systems/snotra/services/` (the doors that moved in plan 129) and `bin/time/snotra/` (the survivors, still current):

| Door | What it does |
|---|---|
| `snotra-bot.sh join <meet-url>` | **The online door.** Send Snotra into a Meet/Zoom/Teams call as a participant via Vexa; she captures from inside the call. Every online meeting is heard this way — never by the microphone. |
| `snotra-capture.sh start [seconds]` | **The local-room door only.** Capture mic + system audio for a meeting of people physically in the room. Refuses (exit 2) unless `SNOTRA_LOCAL_ROOM=1`: the Allfather's law, 2026-10-31 — *the mic is never an online meeting*. |
| `snotra-capture.sh stop` | Stop the running capture. |
| `snotra-bot.sh join <meet-url>` | Send Snotra into a meeting as a participant via Vexa (she captures from inside the call). |
| `snotra-bot.sh status <id>` | Bot status. `idle` with no `bot_container_id` means the worker never spawned — not "joined". |
| `snotra-bot.sh stop <id>` | Remove the bot. |
| `snotra-autojoin.sh` | Read the calendar and auto-join meetings Snotra should attend. |
| `calendar-invite.sh create ... --meet` | Create a Google Calendar event with a Meet link. |
| `mail-send.sh draft/send` | Draft or send email via the Gmail vault grant. |

**Rule:** Snotra listens two ways — locally (capture) or by joining (bot). The
bot needs the Vexa worker running on the server to actually spawn a container;
if `status` shows `idle` with no container, the worker is down and the bot is
not in the call.
