# The doors — every grammar, every exit code

All doors live in `systems/snotra/`. `-h` prints the door's own header. Exit codes are uniform:

```
0  the door did what it says
1  the door answered NO — and said why in one sentence (a mismatch, an empty transcript, drift, a refusal)
2  usage
```

## Harvesting the meeting's own sound

```bash
snotra-harvest.sh status   <meeting-dir>
snotra-harvest.sh fetch    <meeting-dir> [--force]
snotra-harvest.sh verify   <meeting-dir>
snotra-harvest.sh speakers <meeting-dir> [--force]
snotra-harvest.sh signal   <meeting-dir> [--force]
```

| door | does | proves |
|---|---|---|
| `status` | reads the bot store over its HTTP API by the record's Meet code | the record's join key resolves to a real recording |
| `fetch` | downloads the audio, verifies the byte count against `file_size_bytes`, records sha256 | the bytes are the store's bytes (measured: `161 665 525 B`, sha identical to 682 chunks joined by hand) |
| `verify` | re-hashes what is staged against the manifest | the file did not change under us; after the ladder it verifies the compressed file and reports the store's original declaration |
| `speakers` | splits the capture log by `speakerIndex` into one WAV per speaker | 11 923 frames → 3 tracks on the 22 Oct meeting |
| `signal` | audits the bot's STT log | **8 191 calls at `ok:true` with zero words** → exit 1, with the sentence |

Config (Rule 07): `VEXA_API_URL` (default `http://127.0.0.1:18080`), `VEXA_USER_ID` (1), `VEXA_S3_ENDPOINT`,
`VEXA_S3_BUCKET` (`vexa`), `VEXA_S3_ACCESS_KEY`/`_SECRET_KEY` (else `MINIO_*` from the deployed compose
`.env`, found by the docker label), `VEXA_COMPOSE_ENV`, `SNOTRA_HARVEST_DIR`.

## Making the text

```bash
snotra-transcribe-bot.sh run    <meeting-dir> [--force] [--model FILE]
snotra-transcribe-bot.sh status <meeting-dir>
```

Refuses audio that is not the meeting's own (`is_meeting_stream: true` — Rule 33), decodes to 16 kHz mono,
runs whisper.cpp, and writes `evidence/bot/transcript.bot.txt` + `.srt` + `transcribe.json` (engine, model,
seconds, words, sha256 of the audio it read). **Fewer than 50 words is a failure.** `SNOTRA_WHISPER_MODEL`
overrides the model.

## The board

```bash
snotra-project.sh plan   <meeting-dir> [--place company/place]   # no writes
snotra-project.sh apply  <meeting-dir> [--place …] [--move]
snotra-project.sh verify <meeting-dir>
```

Cards go where the **place** says, resolved by NAME through `trello-map.yaml`. Idempotent by
`record-key: <meeting>:<item>` in the description. Each card carries a **member**, a **due date** (actions),
a **checklist** (`Definition of done`, or `To confirm` for a proposed decision), a grade label, and a body
built for Trello's renderer. A card in another list is **drift**: reported, never moved without `--move`.

## The agenda

```bash
snotra-agenda.sh plan|apply|verify <meeting-dir> [--date YYYY-MM-DD]
```

Points in the room's order — what is still `proposed` → actions due by the date → **open questions, last,
always** — every line citing its `DEC-`/`ACT-`/`OQ-` id, with the chair named and the lead time from the
place's cadence.

## The letters

```bash
snotra-letter.sh render <meeting-dir>            # letters/<person>.{txt,html,md} — nothing sent
snotra-letter.sh draft  <meeting-dir>            # Gmail drafts: text + html + attachments
snotra-letter.sh status <meeting-dir>
snotra-letter.sh send   <meeting-dir> --approved  # refuses without an approval record
```

## The register

```bash
snotra-promote.sh list|check|log <meeting-dir>
snotra-promote.sh set  <meeting-dir> <ID> accept|reject|hold --by "<name>" [--why "…"] [--dry-run]
```

**A machine may propose; only a person may promote.** `--by` is required; `validate` runs first; the
promotion is **appended** to `promotions.jsonl` (`from → to · by · why · when`); the state is read back; a
repeat is a `noop`.

## The folder

```bash
snotra-layout.sh check|apply|list <meeting-dir>
```

The top level holds the source, the rendered set, the shelves (`briefs/ letters/ evidence/`), the manifest
(`README.md`, `PROVENANCE.md`) and the named state. Anything else is a **stray**; `apply` moves it to
`evidence/hand-built/` and notes it in `PROVENANCE.md`. Never deletes.

## The sound, afterwards

```bash
snotra-audio-ladder.sh plan|apply|status <meeting-dir> [--offload DIR]
audio-retention.sh scan|apply [--hours 24] [--cap-mb 2048] [--archive DIR]
```

`ladder` verifies → requires a transcript → compresses to Opus 16 kbps mono → strips the duplicated `pcm`
from the capture log. `audio-retention` scans **every** meetings shelf for audio past its fuse.

## The gates

```bash
smoke.sh [meeting-dir]                          # 9 checks, 3 verdicts, a clean skip printed
snotra-pipeline.sh run <meeting-dir>            # the whole chain, locked, logged to Runes
trello-map.sh [--show|--resolve "<board>" "<list>"]   # the board map, refreshed by hand
meeting-record-guard.sh check|fix               # a tracked record missing from disk is restored
```
