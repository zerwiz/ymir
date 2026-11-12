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
