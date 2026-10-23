# Snotra — the meeting, from sound to work

Snotra is the house's **meeting ear and recorder**: it hears the meeting, writes the record, puts the work
on the board, and sends the letters. This shelf is the whole of it — the surfaces, the doors, the contracts,
the laws and the runbook.

> **Snotra is the subsystem, not a script.** Every door below lives in `bin/time/snotra/`. Every meeting
> lives under `svartalfaheim/<company>/meetings/<YYYY-MM-DD>-<slug>/` in the vault, and every board sits
> behind a **place profile** in `hodd/identity/places/`.

## The shelf

| page | what it answers |
|---|---|
| [the-pipeline.md](the-pipeline.md) | the chain from a meeting to a boarded record — one command, its failure semantics, the runbook and the cron |
| [the-doors.md](the-doors.md) | every door: grammar, exit codes, one worked example each |
| [the-places.md](the-places.md) | the place profile: how a company's layout is declared, and how a second company differs without a code change |
| [the-record.md](the-record.md) | the record's schema, the folder standard, the decision state machine, the coverage honesty rules |
| [the-letters.md](the-letters.md) | the letter per participant: structure, plain-text rules, the HTML design, the approval gate |
| [the-sound.md](the-sound.md) | the bot's store, the harvest, the ladder, and the number that matters (590 MiB → 20 MiB) |

## The data flow, once

```
the room ──► the bot (Vexa) ──► its store: 682 webm chunks + a per-frame capture log (speakerIndex)
                                   │
              snotra-harvest ──────┘  fetch · verify byte-for-byte · stage OUTSIDE the vault
                                   │
                                   ├─► snotra-harvest speakers   one WAV per speakerIndex
                                   └─► snotra-transcribe-bot      whisper.cpp → evidence/bot/transcript.bot.txt
                                   │
              the record  ◄────────┘  record.json in the vault (the only source of truth)
                                   │
        ┌──────────────────────────┼───────────────────────────┐
        ▼                          ▼                           ▼
  snotra-project            snotra-agenda              snotra-letter
  cards by kind,            the dated agenda card      one letter per participant,
  member + due + checklist  (proposed → due → OQ last)  text + html + attachments
        │                          │                           │
        ▼                          ▼                           ▼
   Documentation board       Next Meeting Agenda        Gmail drafts → approval → send
                                   │
                          snotra-promote ── accept · reject · hold ──► promotions.jsonl
```

## The laws (short form — full text in [the-record.md](the-record.md) and `RULES/`)

1. **The record is the only source.** A card, an agenda line or a letter cannot contain what `record.json`
   does not hold.
2. **Cards are a projection, never a second truth.** Idempotent by `record-key: <meeting>:<item>`; a card a
   human moved is reported as drift and **left where it is**.
3. **No microphone is a record (Rule 33).** Snotra hears the meeting's own stream — the bot as a participant,
   a monitor/loopback, or per-speaker turns. A room mic is refused by the door.
4. **No transcript, no shrinking (Rule 30).** Audio is evidence with a fuse; the text is the record. The
   ladder refuses to compress or delete before a verified transcript exists.
5. **No agent sends mail.** `send` needs `--approved` **and** a valid `snotra-approve.sh` record bound to the
   draft's exact bytes.
6. **Never delete (Rule 11).** A stray, a superseded source, a hand-built letter — all move to
   `evidence/`, never into the void.
7. **The shape belongs to the place.** A door carries mechanisms; `places/<company>/<place>/place.yaml`
   carries the lists, labels, cadence, roles, retention and the decisions they come from.
8. **A silent success is a defect.** 8 191 transcription calls that returned `ok: true` with no words are
   why `signal` exists and why an empty transcript is a FAILURE.
9. **A clean skip is a pass (Rule 25).** "Not tested" must never look like "passes": every door and every
   smoke check prints its skip *with its reason*.

## Where things live

```
bin/time/snotra/                     the doors (see the-doors.md)
hodd/identity/places/<c>/<p>/        the place profiles (see the-places.md)
hodd/identity/trello-map.yaml        the board map: names → real ids, refreshed by trello-map.sh
svartalfaheim/<company>/meetings/    the meeting folders (see the-record.md)
~/.local/state/ymir/snotra-harvest/  the staging shelf: raw audio, capture logs, speaker WAVs (never in git)
$YMIR_HOME/hodd/memory/runes_audit.md  every pipeline run appends a rune
```

## Status (measured 2026-10-23, this seat)

| meeting | cards | smoke | letters |
|---|---|---|---|
| `2026-10-22-sync-reygan-craig` | 22 verified · 0 drift | 9 pass · 0 skip · 0 fail | 3 drafted, 5 attachments each, **unsent** |
| `2026-10-20-roadmap` | 35 verified · 0 drift | 6 pass · 2 skip · 0 fail | 4 rendered, not drafted |

Not yet built, and named rather than hidden: **the Gimlé adapter** (a place declaring `surface: gimle` is
refused, never cross-filed) · **per-speaker naming** (three tracks exist; naming is a reviewed alias match) ·
**the 24 decisions across both meetings are still `proposed`** — the register awaits a person's signature.
