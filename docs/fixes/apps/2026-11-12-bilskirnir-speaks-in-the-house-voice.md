# Bilskirnir speaks in the house's own voice, not xAI's

**2026-11-12 · component: apps · `apps/bilskirnir/server/src/voice-house.ts` · `voice.ts` · `web/src/voice/` · `setup.sh`**

## What was wrong

Bot HQ's voice called xAI's cloud for everything: the call, the voice list, the preview and the composer's dictation.
With no xAI key the hall showed "Could not start a voice session" and "Transcription failed". The server also refused
to start at all without `XAI_API_KEY`.

The house already has every part this needs. Plan 259 named the road: Bilskirnir's voice through Rödd's pipeline.

## What was done

A second road was added, and it is the default. `BILSKIRNIR_VOICE=house|xai` picks it.

| What the user does | The house road | Proof |
|---|---|---|
| Presses the mic in the composer | The browser's recording goes to the server, which runs whisper.cpp (`whisper-cli`, `ggml-small.en.bin`) | A headless Chromium with a fake mic put "Hello, Allfather. This is Nana in the Hall." into the composer |
| Starts a voice chat | The browser opens `/api/voice/realtime` on the hall's own origin; the server checks the session cookie and relays to Rödd's realtime engine (`speech-to-speech`, `:8890`) | The browser opened one socket, to the hall; the engine stand-in received Nanna's instructions, five relay tools and voice `af_nicole`; no other host was contacted |
| Opens the voice list or presses Preview | Kokoro's voices, Rödd's five first; Preview is spoken by `kokoro-serve` (woken if asleep) | 180 KB of 24 kHz speech returned; the list shows "Nicole · American, woman" |

The call needed almost no new client code. Rödd's engine speaks the OpenAI Realtime protocol, which is the protocol
Bot HQ's call code already spoke to xAI. The session the hall sends was validated against the engine's own parser
(`SessionUpdateEvent`): a realtime session, server VAD with barge-in under `audio.input`, five tools, 24 kHz both ways.

`setup.sh --check` now reports the ear, the mouth and the engine. A missing ear fails the check. A sleeping Kokoro or
a lowered engine is reported, because each is raised on demand.

`XAI_API_KEY` is now needed only on the xAI road; without it, X search fails with its own error.

## What was not changed

- **Rödd itself** — it is the reference app. Nothing under `apps/rodd/` or `bin/voice/` was touched.
- **The engine is never raised by the hall.** Raising it is the voice door's business (`bin/voice/voice-door.sh host`).
  It was not raised for the test either: its Kokoro runs on CUDA beside the display, the condition tied to the browser
  deaths of 2026-11-11, and the Allfather was working on that desk. The real-engine step in `tests/house-voice.mts`
  runs when the engine is up and says it skipped when it is not.

> [!IMPORTANT]
> Owed: one live call against the raised engine, heard by the Allfather, to confirm Nanna answers in Kokoro's voice.
> Every part is proven; the whole, with the real engine, is not.

## Limits

- The house road speaks English only: the ear is `small.en`, so the language list offers English and auto-detect.
- The engine has one seat. A call while Rödd holds it is refused with "busy in another window".
- A call's summary on the house road is a plain line from the call itself, not a model's summary.

## CHANGE LOG

- **2026-11-12** — the house road built and made the default (Eindri `hall-voice`, at the Allfather's word via Hœnir).
