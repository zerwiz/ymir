## snotra · 2026-10-23 — the bot had the meeting, and no door could reach it

### Files
- `bin/time/snotra/snotra-harvest.{sh,py}` (new)
- `bin/time/snotra/snotra-project.{sh,py}` (new)
- `bin/time/snotra/snotra-letter.{sh,py}` (new)
- `bin/time/snotra/snotra-audio-ladder.{sh,py}` (new)
- `bin/time/snotra/trello_client.py` (new — one grant, one resolver)
- `bin/time/snotra/audio-retention.sh` (every meetings shelf discovered, not one hard-coded path)
- `bin/time/snotra/smoke.sh` (new gate)
- `docs/features/the-meeting-becomes-work.md`, `FEATURES.md`

### What was wrong (measured 2026-10-23)
The meeting folder held the **laptop microphone** and no transcript, while the meeting's own audio sat in
the bot's store with no door reaching it:

- `grep -rn 'recordings|playback_url|storage_path' bin/time/snotra/` → nothing.
- `stt.jsonl` for the 22 Oct meeting: **8 191 lines**, every one `{"ok":true,"text":""}`; the
  `transcriptions` table held **0 rows**. Eight thousand silent successes.
- `audio-retention.sh scan` reported **0 files / 0 B** — it scanned `hodd/life/meetings` only, while the
  company meetings live in `svartalfaheim/<realm>/meetings/`, and its code never touched the bot store
  although its header promised to.
- the projector filed only the **actions**, to a board of its own choosing; `cards.json` carried 3 cards
  and none of the 14 decisions.
- the letter that went out said *"no decisions were taken"*.

### What now stands
- **harvest** — the meeting's own audio over the stack's HTTP API, verified against `file_size_bytes`:
  `161 665 525 B`, sha256 identical to the 682 chunks joined by hand. Staged **outside the vault**.
- **speakers** — the capture log split by `speakerIndex` (11 923 frames → 3 tracks).
- **signal** — the STT audit, and it **exits 1** on this meeting with *"8 191 transcription call(s)
  reported ok and produced no words"*.
- **project** — 22 cards (14 decisions · 3 actions · 4 questions · the meeting), each verified by reading
  the returned object back; a second run creates nothing (idempotent by `record-key`).
- **letters** — three, from the record alone, drafted; `send` refuses without an approval record.
- **ladder** — 154 MiB → **19 MiB** Opus 16 kbps mono (duration identical, 10 237 s), and the duplicated
  `pcm` stripped: 250 MiB → **1 MiB**, timing and `speakerIndex` kept. It refused to run until a 21 446-word
  transcript existed.
- **the shape is per place** — `places/<company>/<place>/place.yaml`; a second place (Whynot's Control
  Tower) files correctly with **no code change**, and a place declaring `surface: gimle` is **refused**
  rather than cross-filed.

### The gates
- `bin/time/snotra/smoke.sh` — 6 checks, 3 verdicts, a clean skip printed: **6 pass · 0 skip · 0 fail**.
- `defaults-guard` refused the first push (two doors restated `~/Documents/ymirhome`); the hoard is now
  resolved through `bin/vault/hoard-lib.sh` in every new file.
