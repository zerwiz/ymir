# Rödd says why, in a sentence and one action

**Date:** 2026-11-12 · **Component:** rodd · **Door:** `apps/rodd/patch/why.js` · **Plan:** 271

## What was wrong

A failed connect showed `[object Event]`: a WebSocket error is an Event, and `String()` of it says nothing.

## What was forged

Only the error path changed. `why.js` maps each failure to one sentence and one action: engine down,
microphone held (by whom), microphone refused or missing, the head refused, the seat busy, or a dropped line.
The toolbox's new `GET /desk` supplies the two facts a browser cannot know: whether the engine answers and who
holds the microphone. `patch-ui.py` wires it into the fetched UI, idempotently. A dropped line is never blamed
on a call unless the cause is proven. Rödd's start and restart also pass `--now` to the voice door, because
the operator pressed them.

Proof: `node apps/rodd/smoke/why.test.mjs` shows each cause as its sentence.

## Appended — the four rules of plan 259 B2e

Rödd now follows the four rules a room's voice must obey, in `apps/rodd/patch/why.js`:

1. **Never assume a device.** No microphone at all is a stated cause (`no-input`), read from the new `inputs`
   count in the toolbox's `/desk`, not a silent mute.
2. **Reconnect on its own.** A lost stream (line dropped, track ended, engine down, device missing) is
   re-opened in place: three tries at 0.8 s, 2.2 s and 4 s, so the last starts inside five seconds. A refused
   key or a refused permission is not retried blindly.
3. **Name what it lost, with the time.** "Microphone stream lost at 14:05:03, re-opened at 14:05:05." is
   shown in the window and written to the console log; a loss that does not come back says so plainly.
4. **One record per loss.** `POST /loss` on the toolbox appends one row to `hodd/state/rodd/losses.jsonl`,
   keyed by the second the stream was lost; a duplicate is ignored.

Nothing here, and nothing in the guard, restarts pipewire, wireplumber or any audio unit: the sound server is
shared, and that remedy drops every other client. The smoke test searches for it. A track that ends under a
live call now raises the loss path.

Proof: the same smoke test, on a virtual clock (no engine, no window, no audio device). Not proven: the
30-minute unplug test of B2e, which needs the operator's desk.

## CHANGE LOG

- **2026-11-12** — written by its errand; change-log section added at the gather.
