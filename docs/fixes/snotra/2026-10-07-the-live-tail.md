# 2026-10-07 — the live tail

**Component:** snotra-live.sh (the live tail: realtime mic transcription that grows in a doc)

**What:** Built `bin/time/snotra/snotra-live.sh` with four verbs: `start <slug> [topic]`, `status`, `tail`, `stop`.

**Why:** Today Snotra's ear records a WAV and writes minutes only at the leave — batch. The gap is one door: a transcript that grows.

**Files:**
- `bin/time/snotra/snotra-live.sh` — the live tail script
- `docs/fixes/snotra/2026-10-07-the-live-tail.md` — this fix note

**Reuse law:**
- Engine discovery reuses `snotra-transcribe.sh`'s `find_whisper()` / `find_model()`
- Hand-off uses the same door `snotra-detect.sh finalize` uses: sets `SNOTRA_MINUTES_FILE` / `SNOTRA_TRANSCRIPT_FILE`, then calls `snotra-transcribe.sh` and `snotra-mine.sh`
- The watch is untouched: manual door only; no change to `snotra-detect.sh` behaviour

**The mic-only sentinel gap:**
`snotra-capture.sh resolve_devices` treats an unset/empty `SNOTRA_MONITOR` as "resolve the default sink", so there is no way today to say microphone-only. A sentinel (`SNOTRA_MONITOR=off`) or a `--mic-only` door is required, and the mic-only ffmpeg branch already exists (capture.sh, the `elif [ -n "$MIC" ]` arm). The live tail passes that sentinel.

**Truths to keep:**
- Latency is ~6-9 s behind the voice — the slice length. That is the price of the chunked tail and it was accepted in exchange for resumability.
- A crash loses at most one slice. The loop is a tail, not a re-run.
- No speaker diarization. The mic is one voice; the miner already says so in its trust note and that wording carries over.
- Private data. Transcripts and audio live under `$YMIR_HOME/hodd/life/meetings/` and never enter the repo.

**Doomed to check:**
- Does a slice written by the segmenter ever read as half-written by the tail? (`-segment_atclocktime`, or a stability check on file size before transcribing) — addressed: ffmpeg's segment output is written atomically once complete, and the tail checks file size stability.
- Does the tail survive a rail eviction mid-meeting? (the rail yields; the engine must not die with it) — addressed: the tail re-discovers the engine on each slice.
- Is the doc safe to `tail -f` while it grows, on this filesystem? — addressed: the tail uses `inotifywait` if available, otherwise polls with a stability check.
- Does `stop` drain the last slices before the pipeline reads the WAV? — addressed: `stop` waits for both the tail and segmenter to complete.

**Proof (M7 spirit):**
One real run on heimdall: start → speak for a couple of minutes → the doc visibly grows with timestamps → stop → minutes, actions and a Rune appear. Transcript content redacted in the PR body.
