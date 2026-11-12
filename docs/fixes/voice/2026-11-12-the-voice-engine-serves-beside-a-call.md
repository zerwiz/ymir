# The voice engine serves beside a call, off the display GPU

**Date:** 2026-11-12 · **Component:** voice · **Door:** `bin/voice/voice-door.sh` · **Plan:** 271

## What was wrong

The door refused to raise the engine while any program held the microphone, although the `serve` road opens
no microphone: Rödd's window captures through the browser. The engine also put Kokoro and the ear on the
card that drives the display on a dev seat.

## What was forged

- `host` no longer refuses on a held microphone. It asks the in-call guard, and the operator's `--now` (which
  Rödd passes) goes through.
- On a dev seat the engine runs on the CPU whatever was asked (`--device cpu`, the card hidden), the same pin
  as `kokoro-serve`.
- The `talk` road, which does open a capture device, keeps its refusal. It also refuses a Bluetooth headset
  with that reason, because opening a capture stream there flips the profile and drops the call's audio.
  `YMIR_VOICE_INPUT_DEVICE` names the source to capture from.
- `YMIR_VOICE_DRY=1` prints what `host` would raise and changes nothing.

## Proof, and its limit

`bin/voice/tests/test_voice_beside_call.sh` plants a call on a stand-in sound server and shims the capture
tools: the bare `host` is refused naming Discord, `host --now` pins the CPU and hides the card, and no
capture tool is opened. No real engine was raised and no real call was involved; a trial beside a live call
is still owed by the operator.

## CHANGE LOG

- **2026-11-12** — written by its errand; change-log section added at the gather.
