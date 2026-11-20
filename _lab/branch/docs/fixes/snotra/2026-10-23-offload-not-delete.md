## snotra · 2026-10-23 — offload the compressed audio, never delete it

The first `apply` of `audio-retention.sh` removed two `.opus` files — already-compressed audio — because
the `.opus` branch deleted unconditionally. Their **transcripts survived**, so no meeting was lost, but
destroying the audio is the opposite of the request: the Allfather asked for it to be **moved to a drive**,
not burned.

```
correction[2]{case,was,now}:
  "raw capture (.wav/.ogg/.mp3/.webm)","compressed to Opus, source deleted only after a verified encode","unchanged"
  "already-compressed (.opus)","**deleted**","**offloaded** to `--archive` (filed by month) or, with no cold shelf configured, **kept**"
```

**Measured the same night — the number that justifies the rule:** a 30-minute microphone capture of the
Synteon call, **60 MB of WAV**, became **5.3 MB of Opus** (11×) with its 1,386-word transcript stored
beside it. The meetings shelf went from **54 MB of raw audio to 5.4 MB** of text plus compressed audio.

**Rule 30, restated in the operator's own words:** storage on this machine first, then one of his drives
to offload, then whynot's disks — and the transcript is what must never be lost.
