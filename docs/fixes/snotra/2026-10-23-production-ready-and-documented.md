## snotra · 2026-10-23 — production ready as a command, and documented as a system

### Files
- `bin/time/snotra/snotra-transcribe-bot.{sh,py}` (new — the step that was done by hand)
- `bin/time/snotra/snotra-pipeline.sh` (new — one command, locked, ordered, logged)
- `bin/time/snotra/snotra-transcribe-bot.py` (the decode WAV goes to staging, not the vault)
- `docs/snotra/` (new shelf: README · the-pipeline · the-doors · the-places · the-record · the-letters · the-sound)
- `docs/features/the-meeting-becomes-work.md`, `FEATURES.md` (the shelf is linked from both)

### What was missing
- **The transcription was a hand-built step.** The pipeline could not be unattended while one step was a shell
  one-liner: there was no door that took the harvested audio and produced `transcript.bot.txt` with its
  provenance.
- **There was no single command.** Nine doors existed and the order between them lived in a human's head.
- **There was no specification.** Two how-to pages existed; nothing described the chain, the contracts and the
  failure semantics together, so every new hand re-derived them (and re-derived them wrong).

### What now stands
- `snotra-transcribe-bot.sh` — refuses audio that is not the meeting's own stream (Rule 33), decodes to 16 kHz
  mono **on the staging shelf**, runs whisper.cpp, writes the txt/srt plus `transcribe.json` (engine, model,
  span, words, sha256), and treats fewer than 50 words as a failure.
- `snotra-pipeline.sh` — `record → harvest → signal → transcribe → speakers → layout → project → agenda →
  letters` (+ `--draft`, `--shrink`), one meeting at a time (flock), `--recent N` for a nightly sweep,
  `--dry-run` that writes nothing, and **one rune per run**. A broken vendor STT is a **WARN** when our own
  transcript stands in, and a **FAIL** only when nothing produced text.
- **Measured, real run:** `9 pass · 1 warn · 2 skip · 0 fail` on the 22 October meeting.
- **A fault found by running it:** the decode WAV (327 MB) landed inside the vault in `evidence/bot/`; it was
  moved to staging and the door now writes it there.
- `docs/snotra/` — seven pages: the map and nine laws, the pipeline and runbook, every door, the place
  contract, the record schema and state machine, the letters (plain-text rules + WCAG) and the sound.

### Still not ready, named
The cron line (documented, not installed) · the Gimlé adapter · per-speaker naming · the 24 decisions await a
person's signature · the 20 October letters are rendered, not drafted.
