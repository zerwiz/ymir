## snotra · 2026-10-23 — audio is ephemeral: three tiers, one format, and a transcript before a deletion

**His words:** *"we need to have some rule for the data so it don't grow unproportionally on all the sound we are
capturing… we need to get the meetings to transcripts mainly and have load off for the wavs"* — and then the
tiering: *"storage on this computer first, then connect one of my drives to offload … or send to whynot."*

**The law (new):** `RULES/30-audio-is-ephemeral.md`.

```
law[5]{rule,why}:
  "a recording is a means, not a record","the transcript and the minutes are the record"
  "no audio without a transcript","a deleted meeting with no text is a lost meeting — measured on the first run: 2 transcribed tails compressed and removed, a 47 MB raw capture KEPT"
  "audio has a clock","24 hours by default (SNOTRA_AUDIO_HOURS), then it goes, and the operator is told"
  "the shelves have caps","meeting audio ≤ 2 GiB, bot storage ≤ 2 GiB; over a cap the OLDEST goes first, never the newest"
  "text is cheap and stays","transcripts, minutes, cards and decisions are kilobytes where audio is hundreds of megabytes"
```

**The door:** `bin/time/snotra/audio-retention.sh scan|apply`, three tiers —

```
hot      this machine             Opus 24 kbit/s mono, after transcription, 24 h clock
cold     the operator's drive     --archive /run/media/$USER/<disk>   → filed by month
far      whynot's disks           --send whynot:/srv/audio            → rsync, verified
record   transcripts + minutes    text, forever (Rule 06)
```

**Measured the same night:** `4 MB → 29 KB`, `2 MB → 144 KB` — speech loses nothing a transcript needs.
Compression happens BEFORE any deletion, and a failed encode leaves the source where it was.

**Nightly:** `@dev 03:30 bin/time/snotra/audio-retention.sh apply` in the cron file.

**Also this night, from the same root:** the Telegram live relay was stopped by his word (*"we can stop
listening to telegram, it grows crazy"*) — a live tail belongs in a chat only while someone is reading it.

**Verified:** `scan` lists five files across the meetings shelf and `/tmp` with a per-file verdict; `apply`
compressed the two transcribed meetings and removed their WAVs, and kept every file without a transcript.
