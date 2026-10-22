## snotra · unversioned · 2026-10-22 — the key in the wrong hand, and the voice that was never wired

### What

Two faults kept Snotra out of a live Google Meet on 2026-10-22. Both were silent, and both
were found only because a meeting the Allfather was sitting in had no Snotra in it.

1. **The key was sent in the wrong header.** `snotra-bot.sh` authenticated with
   `Authorization: Bearer $KEY`. The Vexa API answers that with
   `401 {"detail":"Missing API key"}`; it wants `X-API-Key`. Every autojoin this door
   attempted therefore died at the first request — and `snotra-autojoin.sh` reports a failed
   join as a line on stderr while still printing `JOIN`, so the plan looked executed.
   The health probe made the same mistake in the same direction: `/health` does not
   authenticate at all, so it answered **200 to any header**. A green probe over a dead grant.

   Fixed: both the probe and the API call now send `X-API-Key`. Verified against the live
   gateway — `snotra-bot.sh status 4` → `bot 4 active`.

2. **No transcription backend, so the bot was never spawned.** With
   `TRANSCRIPTION_SERVICE_URL` and `TRANSCRIPTION_SERVICE_TOKEN` empty in the Vexa stack's
   `.env`, `POST /bots` refuses with
   `503 no transcription backend configured`. `POST /meetings` still answers **201** and parks
   a record at status `idle` that nothing dispatches — a record is not a participant.
   Setting `TRANSCRIBE_ENABLED=false` lets the stack spawn a bot that listens without
   transcribing; Snotra then joined (`requested → joining → awaiting_admission → active`,
   bot `mtg-4-b552ef2f`).

3. **The voice existed only on paper.** Plan 87 named `snotra-voice-device.sh` (present but
   never run) and `snotra-speak-meeting.sh` (**absent**). This change adds the missing door:
   Kokoro → the `snotra_mic` sink → a client that selects that source, with the speech law
   enforced — announce (the first word names the speaker), a 20-second cap that *refuses*
   rather than trims, a mute file that holds, a Piper fallback whose reason is printed,
   and a Rune per utterance.

### Also fixed in the same pass (seat, not repo)

`kokoro-serve.service` was being killed **795 ms after every start**. The idle-lowering timer
(`kokoro-idle-stop.service`) compared `now` against a stamp file it does not create; a missing
stamp reads as epoch 0, so a fresh service was "idle" for 56 years and stopped on the timer's
next tick. The timer now takes the later of the stamp and the unit's own
`ActiveEnterTimestamp`, and does nothing when neither is known. Kokoro answers
`POST /v1/audio/speech` → `200`, 152 KB wav.

### Verified

- `snotra-bot.sh status 4` → `bot 4 active` (auth proven against the live gateway).
- Snotra joined a real Meet and was logged hearing both participants as speaker streams.
- `snotra-speak-meeting.sh status | say --dry-run` → correct device, correct seconds, the
  announcement prepended on the first utterance.
- Kokoro `POST /v1/audio/speech` → 200 after the idle-stop fix.
- The virtual source `snotra_mic` exists; `pw-link` shows `snotra_mic:monitor → input.snotra_mic`.

### Not verified — stated plainly

**No capture client was proven to receive the voice.** `parec` and `ffmpeg -f pulse` reading
`snotra_mic.monitor` returned digital silence, and `pw-record --target=<node>` recorded the
**default microphone** instead of the target — proven by capturing the target and the default
source simultaneously: both files carried the same room audio (rms ≈1650, identical 440 Hz
amplitude). So the seat-side voice path is **built and half-proven**: the door renders audio and
the sink accepts it, but nothing yet demonstrates a browser (or any capture client) taking
`snotra_mic` as its uplink. That test needs a participant: Chromium joined to a Meet with
`snotra_mic` selected as its microphone, and the remote side confirming they heard it.

**Transcription was off for the 2026-10-22 call** (`TRANSCRIBE_ENABLED=false` was the only way
to spawn a bot), so that meeting produced a recording and speaker streams but no transcript.
Wiring whisper.cpp's `/inference` behind an OpenAI-compatible `/v1/audio/transcriptions` is the
next real step; a `whisper-server` now runs on `127.0.0.1:10300`.
