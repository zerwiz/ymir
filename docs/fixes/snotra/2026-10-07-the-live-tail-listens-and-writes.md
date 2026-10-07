# The live tail — a microphone transcript that writes while you speak

**Dated:** 2026-10-07 · **Component:** snotra · **Branch:** `eindri/snotra-live-tail`
**Found on:** heimdall (16,384 MiB, whisper.cpp CUDA build)

## The want

Snotra's ear hears a call and writes minutes **at the leave**: `snotra-capture.sh`
records one WAV, `snotra-transcribe.sh` reads it whole when the room empties. That
is batch. The Allfather asked for the door that was missing — *start something that
listens and writes the text down in realtime in a document*.

## What was forged

`bin/time/snotra/snotra-live.sh` — `start <slug>` / `status` / `tail` / `stop`.
A **chunked tail**:

```
mic --ffmpeg -f segment -segment_time N--> slices/NNNN.wav
                                            |  a worker, not a replay
                                            v
                                  whisper-cli (the seat's discovered engine)
                                            |  "[hh:mm:ss] text"
                                            v
                        <meetings>/<date>-<lane>-<slug>.live.md   <- grows live
                                            |  at stop
                                            v
                  snotra-transcribe.sh -> minutes ; snotra-mine.sh -> actions
```

Chosen over `whisper-server`'s SSE because the chunked tail **resumes**: a crash
loses at most one slice, and it rides the engine discovery, the VRAM-vs-CPU choice
and the rail-yield that `snotra-transcribe.sh` already owns. The price is ~6–9 s
of lag behind the voice.

At `stop` it joins the slices into one WAV and calls **the same two scripts, with
the same `SNOTRA_MINUTES_FILE` / `SNOTRA_TRANSCRIPT_FILE` convention** that
`snotra-detect.sh finalize` uses. One pipeline, two entrances — never a second one.
The live document keeps its own `.live.md` name so the rolling record and the
polished minutes can never overwrite each other.

**Decided with the Allfather:** chunked tail; a **manual** door (the call-watch
`snotra-detect.sh` is untouched); the existing pipeline at the leave; and **this
machine's microphone only**.

## The gap that had to close first

`snotra-capture.sh resolve_devices` treated an unset `SNOTRA_MONITOR` as "resolve
the default sink". So there was **no way to ask for the microphone alone** — unset
already meant "the system audio". Added the explicit `off` sentinel
(`SNOTRA_MONITOR=off`, `none` accepted) resolving to no monitor, taking the
mic-only ffmpeg branch that already existed in `do_start`. Unset behaviour is
unchanged, so the watch still captures the conversation pair.

## Four defects the live proving turned up

1. **Two doors, one writer.** The worker appended to a copy under `state/` while
   `tail` and the harvest read the file in the hoard — the words grew in one place
   and were read in another. Every writer and reader now names the path through one
   `doc_path()` door.

2. **`start | tee` hung forever.** The background worker inherited stdout and held
   the pipe open, so the shell waited on a writer that never closed. The worker now
   redirects.

3. **The join never reported its path.** `join_wav` returned only an exit code, so
   `stop` could not tell it had a recording and silently skipped the minutes. It now
   prints the path on success and the caller uses it.

4. **The loudest silence of all passed into the record.** The noise filter
   normalised with `tr -d '[]()_*. '` — the underscore was in the delete set, so
   whisper's `BLANK_AUDIO` became `blankaudio` and matched nothing; and its real VAD
   form `[_BLANK_AUDIO_]` matched nothing either. The underscore now survives and is
   trimmed, and a line that is **entirely** a parenthetical annotation
   (`(air whooshing)`, `(footsteps)`) is dropped, because a transcript of what was
   *said* should not carry a noise label.

## Proof on this seat

One real run: `start` → speech played out and picked up by the microphone → the
document grew line by line with `[hh:mm:ss]` stamps → `stop` → transcript, joined
WAV, actions, minutes, and a Rune appended to `runes_audit.md`. Cost measured:
**~1.5 s per slice including model load**, so the tail keeps pace with the mouth and
no resident server is needed.

Text the run produced, verbatim from the live document:

```
[00:00:06] I'll show you my white paper once we're done you can read it
[00:00:12] I'll send you the documentation for the personal engine.
```

## Two truths the code and its docs carry

- **No speaker diarization.** One microphone, one voice; owners are never assigned.
  The miner's trust note says so and the live path does not imply otherwise.
- **The rail yields during a slice.** The rail is the largest claim on the card and
  a meeting is what matters while it is happening, so `SNOTRA_FREE_RAIL` (default
  on) unloads the resident model when CUDA is starved. `SNOTRA_FREE_RAIL=0` is the
  deliberate override for a seat that would rather wait.

## Not verified

- **Dictation-grade accuracy from a human speaking into the mic.** The proofs drove
  TTS through the laptop speakers and let the mic pick it up — a much harder case
  than speech arriving at the microphone.
- Behaviour across an **ffmpeg restart** mid-tail.
- Behaviour when the **rail is evicted mid-meeting** — the yield is wired, the
  mid-flight eviction is not exercised.
- Shell lint: no `shellcheck` on this seat.

## Also in this change

- `bin/model/rail-resolve.sh` walked one level short, so the repo root resolved to
  `bin/` and **every** rail-model resolution refused. Fixed and recorded separately
  in `docs/fixes/runtime/2026-10-07-the-living-rail-resolver-walked-one-level-short.md`.
- The live tail resolves its rail model as `SNOTRA_RAIL_MODEL` → the seat's recorded
  systemd drop-in choice → the resolver's `models[0]`, in that order. Taking
  `models[0]` first is the trap this seat already fell into once: it is
  `apodex-1.0-mini` (21.7 GB, ~36 s) against the summarizer preset's ~5,864 MiB
  and ~15 s.