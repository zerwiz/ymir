# The helm no longer touches the desk while the operator is in a call

**Date:** 2026-11-12 · **Component:** desk · **Door:** `bin/desk/in-call.sh` · **Plan:** 271

## What was wrong

On one afternoon the helm raised the voice engine while the operator was in a Discord call. His microphone
broke, and Discord died by SIGKILL 75 seconds later. The only guard was a microphone check inside
`voice-door.sh host`, and it was the wrong shape: it refused the engine itself, which opens no microphone,
and it did not cover anything else the helm starts at the desk.

## What was forged

- **One guard.** `bin/desk/in-call.sh check` asks the sound server who is capturing and refuses, naming the
  holder, unless the operator passes `--now` (or `YMIR_DESK_NOW=1`). Monitor taps and this house's own voice
  clients are not calls. A server or hand seat has no desk, so the guard reports free there.
- **Every door asks it:** `voice-door.sh host` and `client`, the Electron launcher (`scripts/electron.sh`, new
  windows only), Sessrúmnir's launcher, the Telegram mouth's raise of `kokoro-serve`, and Rödd's model warm-up.
  Rödd's own start and restart pass `--now`, because the operator pressed them.
- **Proof:** `bin/desk/tests/test_in_call.sh` runs against a stand-in sound server.

## Not covered

The guard sees a call only as a capture stream. A call that is listening but not capturing (muted at the
source) is invisible to it.

## CHANGE LOG

- **2026-11-12** — written by its errand; change-log section added at the gather.
