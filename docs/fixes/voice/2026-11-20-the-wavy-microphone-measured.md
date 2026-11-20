# The wavy microphone, measured: the browser's gain control was the swing

**Date:** 2026-11-20 · **Component:** voice · **Plan:** 326.6–326.7

## What was wrong

The operator heard his own voice in Rödd go loud, then very quiet, and the ear struggled to follow him. Four
stages could have been turning the gain. Nobody had measured which one did.

## How it was measured

The same 32 seconds of steady speech (a Kokoro voice, peak-normalised, with a −60 dBFS noise floor) were fed into
Rödd's own Electron as its microphone. Each run used a different set of capture constraints. Each run then
reported the level of one second at a time, in dBFS. The live microphone was then recorded raw and through the
browser at the same moment, so both traces held the same sound.

| Stage | Source trace (speech seconds) | Through the stage | Verdict |
|---|---|---|---|
| Browser, all three on (Rödd's setting) | −26 … −34 | first word at **0 dBFS peak**, −20 … −25, then lower; silence −74 | swings |
| Browser, gain control only | −26 … −34 | **−15** in second 1, **−27** by second 3; silence lifted **−61 → −53** | **the swing** |
| Browser, noise suppression only | −26 … −34 | −28 … −33, silence pushed to −81 | flat on speech |
| Browser, echo cancellation only | −26 … −34 | −27 … −32 | flat |
| Browser, all three off | −26 … −34 | −27 … −32 (within 1 dB) | flat |
| Live microphone, all on, same moment | raw −36 … −44 | **−22 … −40** (18 dB spread) | swings |
| Live microphone, all off, same moment | raw −42 … −47 | −41 … −48 (within 1 dB) | flat |
| The house's echo canceller (`echo-cancel.sh`), live | raw −38 … −42 | −45 … −52, a steady 9 dB cut | flat; not in the chain today, nothing raises it |
| The microphone's hardware AGC | — | the codec (ALC289) exposes no gain-control switch | ruled out by inventory |
| Sample rates | device 48 kHz, page 48 kHz, worklet 48 → 24 kHz (exact 2:1), engine 24 → 16 kHz | the all-off trace runs through the same chain and stays flat | not the swing |

The system's input volume for the built-in microphone sits at **26 % (−35 dB)**. It did not move while the
browser's gain control ran for 36 seconds. That low setting is why a gain control had so much to make up, and why
it rode the voice so hard.

## What changed

- In Rödd's face (repo `zerwiz/rodd`, `patch/steady_mic.py`): `autoGainControl: false` and
  `noiseSuppression: false`; `echoCancellation` stays on, because the speakers share the room. The capture worklet
  now reports the peak beside the RMS, and Settings shows a "your level" line, a peak bar and a ten-second check.
- `bin/voice/echo-cancel.sh` names `webrtc.gain_control = false` instead of trusting the library's default.
- `bin/voice/mic-check.sh` repeats this measurement for anyone: `level`, `trace`, `volume`.

## Proof

- `bin/voice/tests/test_mic_check.sh`: 8 passed, 0 failed.
- The traces above were taken on the dev machine on 2026-11-19 and 2026-11-20, with no call on the desk.

## Still owed

A person speaking for ten seconds into the live window, with the check showing one band. A worker at night does
not speak into the room. The input volume at 26 % is his to raise; the level line now says when it is too quiet.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
