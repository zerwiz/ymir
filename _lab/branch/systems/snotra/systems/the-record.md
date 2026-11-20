# The record — a meeting is a directory

The shape every door in this system agrees on. One record per meeting, one home for it, and **nothing hand-built
beside it**. Enforced by `services/record/snotra-layout.py` (which classifies every file and calls a stray a fault),
written through `services/record/snotra-store.sh`, and mined by `services/record/snotra-mine.sh`.

A record lives in the operator's home — never in this repo:

```
$YMIR_HOME/.../meetings/<YYYYMMDD-HHMM>-<slug>/
```

## What a folder may hold (the standard)

```
the source      record.json · harvest.json · letters.json · promotions.jsonl · transcript.md
the rendered    minutes.md · decisions.md · actions.md · questions.md · dependency-map.md ·
                agenda-next.md · followup-email.md · followup-email.html · email.md · email.html ·
                record.pdf · cards.json · signoff.md
the shelves     briefs/ · letters/ · evidence/
the manifest    README.md · PROVENANCE.md
the declared    trello.json · dispatch.json · signoffs.json · planner.json · classification.yaml ·
   state        timestamp/ · access.jsonl
the evidence    segments.json · candidates.json · review.json · provenance.json · provenance.jsonl
```

Everything else is a **stray**. `apply` MOVES a stray into `evidence/hand-built/` and notes it in `PROVENANCE.md` —
it never deletes (Rule 11). A second hand-built copy of a document the engine already renders is a stray, which is
exactly the fault this standard was written for: one folder once carried four generations of the same letter.

## The laws the record obeys

- **The record is the only source.** Minutes, actions, cards and letters are all rendered FROM it; none is typed
  into place by hand.
- **Audio is ephemeral** (Rule 30): the sound becomes text, then the sound goes. `services/ear/audio-retention.sh`
  is the door that does it, and it refuses to delete sound that has no transcript.
- **Every artifact is sealed.** `services/record/snotra-provenance.sh seal` writes a tamper-evident provenance file;
  `services/record/snotra-evidence.sh` timestamps, certifies and applies a retention rule.
- **A record is restored, not recreated.** `meeting-record-guard.sh` puts a missing record back rather than
  letting a door write a new empty one over the loss.
