## snotra · unversioned · 2026-10-22 — the voice leaves the OS mixer, and the law that says it must stream

### What

A live meeting proved the seat's audio plumbing wrong and this change replaces it.

- **`bin/time/snotra/snotra-cdp.py`** (new) — the meeting page becomes the audio device. `getUserMedia`
  is replaced before Meet's own scripts run, so the microphone Meet receives is a stream we fill over the
  DevTools protocol; every remote track is teed back the same way. Includes `selftest`, the oracle:
  push a sentence, record the same path back, transcribe, compare.
- **`bin/time/snotra/snotra-meet.sh`** (new) — the door: `launch · install · join · selftest · say ·
  run · state · stop`. It raises the voice engine and frees the GPU before speaking.
- **`bin/time/snotra/snotra-voice.py`** (new) — the streaming loop: 100 ms capture, 250 ms ASR step over a
  6 s window, endpointing, SSE compose cut into clauses, sentence-pipelined Kokoro output pushed into the
  page's microphone at wall-clock pace, one sink for the whole answer, per-turn latency in
  `voice-log`. Guards: self-echo, deaf-while-speaking, addressed-in-the-current-chunk, single-flight,
  VRAM, mute, classification, fuzzy subject matching for a mangled noun.
- **`bin/time/snotra/snotra-talk.py`** — page mode, VRAM guard, Skírnir's own digest for composing,
  pipelined sentence speech, and the name test widened to what recognition actually produces.
- **`RULES/28-streaming-voice.md`** (new) — the law this produced: the voice is a pipeline of overlapping
  stages, latency is measured per turn, and a silent failure is a violation.

### Why

Measured on 2026-10-22, in a real Google Meet: every PipeWire route reported success and carried silence
(null-sink monitors read zeros, `pw-record --target` was ignored, `pw-loopback` segfaulted), Vexa's bot
cannot speak (`POST /speak` → 404) and one bot per meeting (409), Kokoro answers `500 CUBLAS failure 3`
when the rail holds the card and the caller counted it as silence, and the loop answered its own voice
because the room mix contains it.

### Verified

- oracle: said *"The mouth carries these words into the room."* → recorded back → match 1.00 (peak 0.794).
- the meeting's own recording (Vexa bot, 80 min) contains the spoken greeting.
- TTFA **1.18 s** (806–1274 ms across runs); ASR 140–390 ms; digest answers in 0.23 s.
- fuzzy subject: *"Skamer, what is Nutra?"* resolves to the OptiCat fact.

### Not verified

- continuity: gaps above 150 ms remain inside one answer (council bar unmet).
- the pcm deviation: Kokoro refuses `response_format: pcm` (400), so the WAV is read progressively.
- research by voice is wired and unproven in a meeting.
