## runtime · 2026-10-23 — "who said what" is not solved, and the split was writing static

### Files
- `bin/time/snotra/snotra-attrib.{sh,py}` (new — list · sample · set · check · apply)
- `bin/time/snotra/snotra-harvest.py` — `speakers` now **verifies the payload** and refuses to write noise
- `docs/snotra/the-record.md` (attribution section)

### The Allfather's rule
*"Snotra must know who is talking for the next meeting so we know who says what. This is a critical rule."*

### What is true today — measured, not assumed
| claim | measurement |
|---|---|
| the bot records **how many** voices | the capture log holds `speakerIndex` per frame: **3 tracks**, 11 923 frames |
| the bot records **when** each spoke | `snotra-attrib check` votes over ±4 s of frames: **16 of 21** record items resolve to a clear track (e.g. `OQ-…-02 → speaker-02, 28/28 frames`); 5 are `unclear` and stay unattributed |
| the bot records **who** | **no.** Nothing maps an index to a person. All 14 decisions read `decided_by: null` |
| the tracks can identify a voice | **NO — and this is the finding.** The capture log's field is named `pcm`; it is not PCM. Decoded as s16le at 16 kHz or 48 kHz it is full-scale noise (mean magnitude **16 354**, max 32 765; speech is 500–4 000), whisper hears `(buzzing)` / `[MUSIC PLAYING]`, while the **master** recording at the same offset transcribes cleanly ("So they make agent run times. And then.") |
| the bot exposes per-participant audio | no — `recordings/590155491635` has exactly **one** media file, the mixed `master.webm` |

**So `snotra-harvest.sh speakers` had been writing three WAV files of static and reporting success.** It now
refuses: it decodes a sample, computes the mean magnitude, and if the payload is not speech it exits with

> *the capture log's `pcm` is not PCM: its frames decode to noise (mean magnitude 16 354, speech is 500–4 000).
> No tracks are written — an audio file that is static is worse than none.*

That is the same disease this house has met four times today (a door that succeeds silently), caught this time by
listening to what the door produced.

### What `snotra-attrib` does, and what it refuses
```bash
snotra-attrib.sh list   <meeting-dir>                     tracks · seconds · frames · the name or "—"
snotra-attrib.sh witness <meeting-dir>                    (sample) a probe per track, for a human to recognise
snotra-attrib.sh set    <meeting-dir> speaker-00 "Name" --by "<who confirms>" [--why "…"]
snotra-attrib.sh check  <meeting-dir>                     the vote: which track held the floor at each quote
snotra-attrib.sh apply  <meeting-dir> --by "<name>"       write decided_by + attribution{} into the record
```

- **naming a voice is a person's claim** — `--by` is required and appended to `speakers.jsonl`, so a re-naming is
  a new line and the earlier claim is never erased;
- **the vote must be clear** — the winner holds ≥ 60 % of the frames within ±4 s, or the item is `unclear` and
  **nothing** is attributed (`decided_by` stays `null`): an honest unknown beats a plausible name (Rule 33);
- `apply` writes `attribution{status: confirmed|unclear, how, vote, confirmed_by, track}` per item.

### The three real routes to names, in order of exactness
1. **the platform's per-participant audio** — Meet/Zoom do not expose it to us; the bot's own product may
   (`transcription_provider` is configurable). Until a per-participant media file exists, this route is closed and
   the record says so.
2. **a voiceprint over the master** — enrol each participant once from a known stretch (e.g. the Allfather alone
   at the start), then match segments of the master. Local, no cloud, and it is the only route that works from the
   audio we actually hold.
3. **a human listen + the timing vote** — the vote already says *which of three voices* held the floor at each
   decision; one listen to three short stretches per meeting names all three, and `speakers.jsonl` keeps the claim.
   This is what works **today**, and it is honest about being a human's judgement.

### For the next meeting
- the bot joins with its own identity and records the master (works);
- the vote runs automatically (`snotra-attrib check`), so every decision arrives with *track evidence*;
- **names arrive only when a person listens once and says who is who** — or when route 2 is built. The next
  letters will therefore say "unattributed" until that happens, and that sentence is the truth, not a bug.

### Correction (2026-10-23, same day) — the commit message lost a word

The first commit for this fix carried a backtick inside a double-quoted message, so the shell ate the word
`pcm` from the subject line. The commit was amended with a message that needs no quoting; the tree did not
change. Recorded here because this house does not rewrite history quietly: an amended message is a correction,
and a correction is written down.
