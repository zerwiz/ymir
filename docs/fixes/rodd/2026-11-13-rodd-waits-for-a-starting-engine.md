# Rödd waits for a starting engine, searches on every machine, and never shows a stale face

**Status:** built and proven on heimdall, 2026-11-13 (plan 275).

Four faults met in one night are fixed here. Each is listed with what was seen, what was wrong, and what changed.

## What changed

| Fault | What was seen | The fix |
|---|---|---|
| A press while the engine loads | "Microphone stream lost at …" while the engine was still loading its models | The desk door reports `engine_starting`; the window waits up to two minutes, says so, and connects the moment the engine answers |
| Every loss was called the microphone | "Microphone stream lost" for a dropped line and for a held seat too | Each loss is named for what it was: the microphone, the line, the engine or the one seat |
| A held seat got three quick knocks | Retries inside five seconds, before the engine had freed the old session | A held seat is knocked on at 3, 8 and 15 seconds |
| A stale face | An update to `main.js` or `house.css` stayed hidden behind Electron's cache | The face's server sends `Cache-Control: no-cache`; an unchanged file costs one 304 |
| No web search on a fresh machine | SearXNG was raised by hand on two machines; nothing in the repo knew it | `bin/voice/search-ensure.sh` keeps it standing, and Rödd's start runs it in the background |
| A wrong Electron was used silently | A tree updated in place kept Electron 33; Rödd's window died with "WebSocket is not defined" | The resolver refuses an Electron whose major differs from the one the app declares, and names the remedy |

## How it was proven

- `node apps/rodd/smoke/why.test.mjs`: 23 checks, including a starting engine, a start that never ends, a held seat and a dropped line, on a virtual clock.
- In Rödd's own window on heimdall: the engine was stopped and started, and the orb was pressed 3 seconds later. The window said "The voice engine is starting — Rödd connects the moment it answers", then "The voice engine was starting at 00:56:58; connected at 00:57:50." It made one knock and said nothing about a microphone.
- The face served on a spare port answered `cache-control: no-cache` with an ETag for every file, and 304 on revalidation.
- `search-ensure.sh` was run on all its roads: already up, stopped then started (5.6 s), a fresh create on a spare port, and a remote URL left alone.

## Files

- `apps/rodd/patch/why.js`, `apps/rodd/smoke/why.test.mjs`
- `apps/rodd/patch/patch-ui.py` (the `no-cache` middleware)
- `bin/voice/voice-toolbox.py` (`engine_starting` on `/desk`)
- `bin/voice/search-ensure.sh` (new), `apps/rodd/start.sh`
- `bin/desktop/electron-lib.sh`
