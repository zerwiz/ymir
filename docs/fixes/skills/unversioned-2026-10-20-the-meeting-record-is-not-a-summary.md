## skills · unversioned · 2026-10-20 — the meeting record is not a summary

### What

The Allfather's brief: *"build the system and test it"* for meeting outcomes —
summaries, decisions, and a task for every person. The gap was real: Ymir had a
meeting **ear** (Snotra: capture, whisper transcript, mechanical commitment
mining) and no meeting **record**. The ear says so itself — no diarization, so
owners are never assigned, and every line is a quote rather than a commitment.

This adds `snotra-meeting-outcomes`: a skill with one deterministic engine that
parses a transcript (TXT, DOCX, or recorder JSON), extracts decision and action
candidates with timestamps and verbatim quotes, merges them with a secretary's
review, validates eight gates, and renders minutes, a decision log, an action
register, per-person briefs, a follow-up email, and Trello card payloads.

The design choice is the record's: **null beats a guess**. The extractor will
omit an owner or a date rather than infer one, and the validator refuses to
publish a record with an unnamed owner, a null date without a `decide_by`, or an
entry without evidence. A model pass is optional and never the authority.

### Files

- `.agents/skills/snotra-meeting-outcomes/SKILL.md`
- `assets/meeting-schema.json`, `minutes-template.md`, `action-register.md`,
  `decision-log.md`, `participant-brief.md`, `followup-email.md`,
  `quality-gates.md`, `trello-mapping.md`, `extraction-prompt.md`,
  `validation-prompt.md`
- `scripts/meeting-outcomes.py` (parse · extract · merge · validate · render ·
  cards · pipeline)
- `tests/test_meeting_outcomes.py` + `tests/fixtures/standup.txt`
- `docs/features/meeting-outcomes.md`, a FEATURES.md row, and a registry row

### Verified

- 21 unit tests pass (`python3 tests/test_meeting_outcomes.py`): parsing, date
  resolution (tomorrow / this week / next week / weekday / day-month / ISO),
  owner inference, evidence, five validator failures, rendering, card shape, and
  curated-over-machine precedence.
- The pipeline was run against a real 158-minute, 3,641-line meeting export
  (DOCX, 4 speakers, 1,142 parsed segments): 6 decisions and 16 actions
  validated cleanly; 8 documents plus `cards.json` were produced.
- The record's own failure path was tested: an unnamed owner, missing evidence,
  a null date without a `decide_by`, and a done card without a definition of done
  each fail validation.

### Not verified

- No Trello, Read AI or Google write was performed: no OAuth grant exists yet on
  this seat. `cards.json` is a payload, not a card.
- The optional model pass was not exercised; the deterministic path is the
  baseline and the only path tested.
