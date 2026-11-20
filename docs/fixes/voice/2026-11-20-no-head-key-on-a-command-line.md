# The head's key no longer rides the voice engine's command line

**Date:** 2026-11-20 · **Component:** voice · **Found while proving:** plan 326.8

## What was wrong

`voice-door.sh host` passed the head's API key to the engine as `--responses_api_api_key <key>`. A command line is
world-readable on Linux: any local user saw the key in `ps`, in `/proc/<pid>/cmdline`, and in the unit's
description in `systemctl --user list-units`.

For an online head the key did nothing at all. The engine talks to the loopback head proxy, and the proxy builds
its own headers with its own key; it never forwards the engine's.

## What changed

- With an online head, the engine is given no key.
- With a local head, the key goes by environment (`OPENAI_API_KEY`, which the engine's client reads). A process's
  environment is readable only by its owner.

## Proof

Measured on the dev machine with the online head:

| Check | Result |
|---|---|
| `api_key` in the engine's `/proc/<pid>/cmdline` | 0 |
| `OPENAI_API_KEY` in the engine's environment | 0 (online: the proxy holds it) |
| `/proc/<pid>/environ` | mode 400, owned by the operator |
| The proxy's start line | `key set` |
| A turn through the head | `status=completed`, the mind answered in 5.3 s |

`YMIR_VOICE_DRY=1 voice-door.sh host --now` still prints the engine line, and `test_voice_idle.sh` passes 6/0.

## Still owed

The key that was exposed is in the head's settings, not in any repository. Rotating it is the operator's call.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
