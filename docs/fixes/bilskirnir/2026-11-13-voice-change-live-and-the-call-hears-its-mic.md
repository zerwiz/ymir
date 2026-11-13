# Bilskirnir: a voice change reaches the running call, and a call that loses its microphone ends itself

**Status:** built and tested in Bilskirnir's window on heimdall, 2026-11-13 (plan 275), at the Allfather's word:
*"I changed voice in Bilskirnir but then it went silent."*

## What was found

- A voice chosen during a call never reached that call; it applied from the next call only.
- The call from 20:29 stayed connected for 38 minutes while the engine heard nothing from the microphone after
  20:33:45, holding one of the engine's two seats; it ended only when a test pressed "End call" at 21:07.
- Every Kokoro voice in the list speaks when asked directly (af_nicole 3.2 s, af_sky 2.3 s, af_bella 2.4 s, am_michael
  2.5 s, bf_emma 2.3 s of audio for one sentence); only a name the engine does not carry ("luna") is silent, and
  Bilskirnir already sends af_nicole in its place.

## What changed

| Part | Change |
|---|---|
| `web/src/voice/call.ts` | `setVoice`: the call's own session sent again with the new voice (`session.update`); `updateCallVoice` exported |
| `web/src/components/VoiceSettings.tsx` | choosing a voice also updates a running call with that agent |
| `web/src/voice/call.ts` | the call watches its microphone: a track that ended ends the call at once; no frames for 15 s wakes the audio; 30 s ends the call — each with a plain message |

## How it was proven

- Mid-call voice change through the panel's select: the engine's session updates went from 214 to 215, and the call
  kept listening.
- The call's microphone track stopped on purpose: the call ended within 12 s (the first version, which only counted
  frames, did not notice — a stopped track still sends silent frames; the track's state is now checked).

> [!WARNING]
> The microphone tests ran while the operator joined a Google Meet in Chromium; at 21:17:39 Chromium killed and
> restarted its own audio service after a run of "Chromium input underrun" lines from 21:13, and Meet lost its speaker
> stream until he re-chose the headset. The cause is not proven; voice tests now wait for the call guard to say the
> desk is free, and the guard did not yet see the Meet at the last check before testing.
