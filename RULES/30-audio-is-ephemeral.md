# 30 — Audio is ephemeral: it exists only to become text

**Opened 2026-10-22** at the Allfather's word — *"we also need to have some rule for the data so it don't grow
unproportionally on all the sound we are capturing… we need to get the meetings to transcripts mainly and
have load off for the wavs"*.

## The law

```
law[5]{rule,why}:
  "a recording is a means, not a record","the transcript and the minutes are the record; the audio exists so a machine can turn speech into text, and nothing else"
  "no audio without a transcript","audio may be deleted only after a transcript exists for it, or on an explicit --force by the operator. A deleted meeting with no text is a lost meeting"
  "audio has a clock","captured audio lives at most 24 hours by default (SNOTRA_AUDIO_HOURS), then it goes — transcribed or not, the operator is told"
  "the shelves have caps","meeting audio ≤ 2 GiB and the meeting-bot's storage ≤ 2 GiB; when a cap is crossed the OLDEST audio goes first, never the newest"
  "text is cheap and stays","transcripts, minutes, decisions and cards are kept; they are kilobytes where audio is hundreds of megabytes"
```

## Why it is a law and not a preference

Measured 2026-10-22, one evening: a single 30-minute meeting left **307 MB of recording chunks** in the bot's
storage and two WAVs in the meetings shelf; the day's earlier experiments had already put ~5.9 MB of
stray WAVs in the meetings shelf and left five headless browsers holding the GPU. Left alone, this grows
without a ceiling and the cost is paid by the vault, the backups, and eventually the card.

## The rule in practice

```sh
systems/snotra/services/ear/audio-retention.sh scan            # what audio exists, per meeting, and what would go
systems/snotra/services/ear/audio-retention.sh apply           # transcribe-if-needed, then delete, oldest first
systems/snotra/services/ear/audio-retention.sh apply --force   # delete even without a transcript (operator only)
```

The nightly cron row runs `apply`; `scan` is for a human. Deleting is never silent: every removal names the
file, its size, whether a transcript existed, and the Rune it wrote.

## What this rule does not say

- It does not say a meeting may go unrecorded. Capture stays; only the AUDIO is ephemeral.
- It does not permit deleting a transcript, a minutes file, or a card. Those follow Rule 06 (append-only).
- It does not apply to the vault's own files: `hodd/secrets/`, `hodd/identity/` and the plans are not audio.

See also: `RULES/06-append-only.md` (what may never be deleted), `RULES/28-streaming-voice.md` (the live loop).

---

## 2026-10-23 — the three tiers, and the format that makes room

The Allfather's word: *"we can have a storage on this computer first and then connect one of my drives to offload
them for storage … or send to whynot servers hard drives."*

```
tiers[4]{tier,what_lives_there,format,when_it_empties}:
  "the hot shelf","this machine, the meetings shelf and the bot's recording volume","**Opus 24 kbit/s mono** — speech is words, not waveforms","after transcription, and at the 24-hour clock"
  "the cold shelf","one of the operator's own drives, plugged in when it is plugged in","the same Opus files, filed by month (`<drive>/YYYY-MM/`)","it does not empty; the drive is the archive"
  "the far shelf","whynot's disks, reached with `--send host:path` (rsync, verified)","the same Opus files","it does not empty"
  "the record","transcripts, minutes, cards, decisions","**text, forever** (Rule 06)","never"
```

**Measured the same night:** `4 MB of room audio → 29 KB of Opus`, `2 MB → 144 KB`. Speech loses nothing
a transcript needs, and the shelf stops growing by hundreds of megabytes an evening.

**The door that does it:** `systems/snotra/services/ear/audio-retention.sh`
- `scan` — what audio exists, its age, whether it has a transcript, and the verdict;
- `apply` — compress first (Opus), then delete the source **only after the encoded file is verified non-empty**;
- `apply --archive /run/media/$USER/<disk>` — file the Opus onto the cold shelf by month;
- `apply --send whynot:/srv/audio` — rsync it to the far shelf (`--remove-source-files`, so a failed send
  never loses the local copy);
- `--force` — delete even without a transcript. Operator only, and it writes a Rune.

**An audio file with no transcript is KEPT, deliberately.** Measured on the first run: the two meeting
tails that had transcripts were compressed and removed (2 files), while a 47 MB raw capture without one
was kept — *Rule 30 refuses to trade a lost meeting for disk space.*

---

## Correction (2026-10-24) — the paths above moved to Snotra's own shelf

Appended, not rewritten (Rule 06). Plan 129 moved the meeting system out of the time shelf on 2026-10-24:
`bin/time/snotra/<door>` became `systems/snotra/services/<service>/<door>`. The command examples in this rule were
repointed on the same day and are live; the move's own record is `.agents/paths-ledger.yaml` (migration
`0014-systems-shelf`) and the fix note `docs/fixes/snotra/2026-10-24-snotra-becomes-a-system.md`.

What this rule names, in its new spelling:
- `audio-retention.sh scan` / `apply` / `apply --force` — the door this rule is enforced by

A shim survives at the old path so nothing breaks while callers are repointed; it is retired by that dated fix
note, never silently. The law in this file is unchanged — only the shelf the doors are kept on.
