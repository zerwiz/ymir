# Every Kokoro voice has a door, and a name finds its voice

**Date:** 2026-11-19 · **Component:** voice · **Plan:** 326.1–326.5

## What was wrong

Kokoro holds 54 voices, but the house could reach them only by an id it already knew. No list showed them,
and no catalogue named them in the home. A spoken wish such as "use Eric" had nothing to resolve against.

## What changed

- `bin/voice/voices.sh` (with `bin/voice/voices.py`) lists every voice from the engine's own list
  (`kokoro voices --json`), never from a hand-kept table.
- A plain name resolves to its id (`eric` → `am_eric`). A name that fits two voices is refused, and the refusal
  names both ids.
- `voices.sh catalogue --home` writes `identity/voices.yaml` into the hoard. It resolves the hoard through
  `bin/vault/hoard-lib.sh` and writes atomically.
- `voices.sh say <voice> [text] [--to <file>]` speaks a sample. Without `--to` it plays sound, so it refuses
  while `bin/desk/in-call.sh holder` names a call.

Measured, and left unchanged: `kokoro-serve` already reads `voice` from each request body and falls back to its
configured default only when a request names none. So 326.5 holds already.

## Proof

- `bin/voice/tests/test_voices.sh`: 9 passed, 0 failed. It is fenced: a fixture list stands in for the engine,
  and `HOME` and `YMIR_HOME` point into a throwaway folder.
- `voices.sh list` printed 54 voices on this machine.
- `voices.sh say eric "…" --to eric.wav` wrote 132,140 bytes as `am_eric`, `en-us`, and played nothing.

## Still owed

Rödd choosing a voice per context is not built here. The door gives it a name-to-id map to read.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
