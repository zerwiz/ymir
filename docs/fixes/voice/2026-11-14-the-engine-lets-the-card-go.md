# The voice engine lets the card go when nobody is on the line

**Date:** 2026-11-14 · **Component:** voice (`bin/voice/voice-idle.sh`, `bin/voice/voice-door.sh`) · **Plan:** 275 item 23

## What was wrong

`ymir-voice-host.service` (the streaming voice engine, `speech-to-speech serve`) is raised on demand and never
lowered. It holds ~2.7 GiB of a 16 GiB card, so at 03:16 on 2026-11-14 the rail had nothing left to load its model
with — `cudaMalloc of 1,184 MiB` failed — and every chat lost its local road while the room was empty and the engine
sat idle.

## The fix

- **A watcher beside the engine.** `voice-door.sh host` now raises `ymir-voice-idle.service` (a transient unit running
  `voice-idle.sh watch`) next to the engine. After `YMIR_VOICE_IDLE_SECONDS` (default **300**, `0` disables) with no
  session in use, it stops `ymir-voice-host.service` and the card is free. Raising the engine is unchanged; this door
  only ever lowers, and only on evidence.
- **The evidence is the engine's own pool.** `GET /v1/pool` → `{size, in_use, units:[{state, draining_for_s}]}`.
  A connected client holds a slot, so a call is never cut off by a quiet moment. A unit left `draining` for more than
  a minute is a client that vanished mid-turn, not a call — counting it would hold the card forever, which is the same
  fault one level down.
- **It says why.** Every stop writes a line to `<home>/hodd/state/voice/idle.log`; `voice-idle.sh status` prints the
  unit's state, whether a call is held, and the window in force.

## Verified

`bin/voice/tests/test_voice_idle.sh` — 6 checks with a fake pool and a fake `systemctl`, so nothing real is stopped:
an engine that is not raised is left alone (no stop is ever issued); a held session keeps the card; a long-draining
session does not hold it forever; after the quiet window the unit is stopped and the reason is logged;
`YMIR_VOICE_IDLE_SECONDS=0` disables it; `status` reports what it sees.

Live on heimdall: `voice-idle.sh status` read the running engine as `up`, `idle — it will let the card go`, and the
pool's two pipelines as not in use.

## Owed, found on the way

The engine is started with `--responses_api_api_key <key>` in its **argv** (`bin/voice/voice-door.sh`), which any
process of the same user can read through `/proc`. It is how that engine takes its key, so closing it needs a change
on the engine's side (an env var or a reading proxy; `bin/voice/head-proxy.py` already exists for the online head).
Recorded here rather than fixed blind.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #757
