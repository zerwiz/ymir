# The sound — where it lives, how it shrinks, and the one number that matters

Audio is the most expensive thing a meeting produces and the least useful afterwards. This page is how the
house keeps it honest: **the text is the record; the sound is evidence with a fuse.**

## Where the meeting's sound actually is

| place | what | who can reach it |
|---|---|---|
| the bot's store (Vexa, `versitygw` S3 on `127.0.0.1:18900`) | one webm chunk per ~15 s + a per-frame capture log with `speakerIndex` | `snotra-harvest.sh` — and, until 2026-10-23, **nothing** |
| the staging shelf `~/.local/state/ymir/snotra-harvest/<meeting>/` | the joined audio, the capture log, per-speaker WAVs, the decode WAV | the doors, the operator |
| the vault `<meeting>/evidence/` | the **text** of the transcript and `transcribe.json`; hand-built strays | git — so no audio here, ever |
| the cold shelf (an external drive / whynot) | the compressed archive, by month | a human, or `--offload` |

**A meeting folder once held a 32-minute room-mic fragment** while 155 MB of the meeting's own audio sat in
the bot store untouched. That is the fault the harvest door ends.

## The ladder

```bash
snotra-audio-ladder.sh plan  <meeting-dir>                    # what would shrink, and by how much
snotra-audio-ladder.sh apply <meeting-dir> [--offload DIR]    # do it
```

Order — and it stops the moment a step cannot be proven:

```
1 verify     sha256 and byte count still match the harvest manifest
2 require    a transcript with ≥50 words — no transcript, NO shrinking (Rule 30)
3 compress   bot.webm → bot.opus, 16 kbps mono 16 kHz — the raw goes only after the opus decodes AND its
             duration is within 2 s of the original
4 strip      signal.jsonl → signal.meta.jsonl: the duplicated `pcm` is dropped, timing and speakerIndex kept
5 keep       the per-speaker WAVs until a per-speaker transcript exists — they are the only copy of the split
```

## The numbers, measured on one 2 h 50 min meeting

| item | before | after |
|---|---|---|
| the bot's audio | 161,665,525 B (154 MiB) | 19,779,897 B (19 MiB, Opus 16 kbps) |
| the capture log | 250 MiB (every frame, base64) | 1 MiB (timing + `speakerIndex`) |
| the transcript | did not exist | 21,446 words, 2,151 timestamped lines |
| projection | — | 150 meetings/month × 153 MB = **23 GB/month raw** → ~**2 GB/month** compressed, and none on the root after offload |

**The rule of thumb:** raw ≈ **150 MB per hour of meeting**, compressed ≈ **20 MB per 2¾ hours**. A terabyte
raw holds ~6,500 meetings; compressed, ~50,000 — and the text alone holds millions.

## Why the old retention door saw nothing

`audio-retention.sh scan` reported `files 0, total 0B` while five recordings sat on disk. Two causes, both
fixed on 2026-10-23:

1. it scanned **one** shelf (`hodd/life/meetings`), while company meetings live in
   `svartalfaheim/<realm>/meetings/` — it now discovers every shelf under the home;
2. its header promised to reach the bot's store and its code never did — the ladder and the harvest are the
   doors that actually reach it.

## What the law requires

- **Rule 30** — audio is ephemeral: transcribed, compressed, offloaded, then gone; text is forever;
- **Rule 33** — a room microphone is **not** a record, and no door will transcribe one as if it were;
- **Rule 11** — a superseded capture is *moved*, never deleted: the 22 Oct room-mic opus lives on in
  `evidence/` as a secondary source, labelled as such in the record's `coverage`;
- **a fix without a test is a claim** — `smoke.sh` asserts the ladder refuses to shrink without a transcript.
