# Meeting outcomes — from recording to accountable action

**What it is.** A repeatable way to turn a meeting recording or transcript into a
record the team can act on: minutes, decisions with their reasons, actions with
one owner and one date, a short brief for each person, a follow-up email, and
cards for Trello.

It is not another note-taker. Read AI, Fathom, Teams and Meet already record and
summarise. This is the layer after them: it decides what counts as a decision,
who owns what, and when it is due — and it refuses to guess.

## What you need

- A transcript. Most recorders export one as text, DOCX or JSON. The skill reads
  all three.
- The meeting date, because "tomorrow" and "next week" are resolved against it.
- A named **Meeting Secretary** for that meeting: the person who reviews the
  draft before anything is sent.
- Python 3. Nothing else. No model, no network, no account.

## Use it

```sh
SCRIPT=.agents/skills/snotra-meeting-outcomes/scripts/meeting-outcomes.py

python3 "$SCRIPT" pipeline meeting.docx \
  --date 2026-10-20 \
  --review review.json \
  --outdir meetings/2026-10-20-topic
```

That writes:

| File | What it is |
|---|---|
| `minutes.md` | the record, with a quote for every decision and action |
| `decisions.md` | the append-only decision log |
| `actions.md` | the register, sortable by owner and date |
| `briefs/<person>.md` | each person's own actions, nothing else |
| `followup-email.md` | ready to send, after review |
| `cards.json` | Trello card payloads — board, title, owner, due date, evidence |

The `review.json` is where the secretary writes the entries they accept. It is
the only file a person has to author; everything else is generated.

## What it refuses to do

- It will not assign an owner the transcript does not name.
- It will not invent a due date from "soon" or "as discussed".
- It will not publish a decision without a timestamp and a quote.
- It will not write a card outside the board's `Inbox` list.
- It will not put meeting content in the Ymir repository.

## Limits

- Speaker labels come from the recorder. A name-correction calibration against
  previously corrected minutes is part of the procedure.
- The automatic extractor is conservative on messy speech. Expect to accept
  some items and reject others; that review is the point, not a failure.
- Relative dates are resolved against the meeting date and flagged when unclear.
- Read AI, Gmail and Drive ingestion need an OAuth grant. Without it, export the
  transcript and run the pipeline on the file.

## If it does not work

| Symptom | Cause | Fix |
|---|---|---|
| `no timestamped segments found` | The export has no timestamps | Export with timestamps, or convert to `[h:mm:ss] text` lines |
| `INVALID — ... owner` | An action has no named owner | Name the owner or move it to the open questions / risks |
| `INVALID — ... decide_by` | A date is null without a decision date | Set `date_unresolved` and `decide_by`, or set a date |
| `INVALID — ... evidence` | A quote or timestamp is missing | Copy the exact transcript line and its timestamp |
| Cards do not appear in Trello | The payload was generated, not sent | Send it through the Trello MCP connection, into `Inbox` |

## Tests

```sh
python3 .agents/skills/snotra-meeting-outcomes/tests/test_meeting_outcomes.py
```

21 tests, no dependencies.
