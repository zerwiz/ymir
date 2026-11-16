# The voice host rises on a Mac

**Date:** 2026-11-16 · **Component:** platforms / voice · **Found while:** connecting Rödd's voice engine on a Mac

## What went wrong

| Where | Fault | Effect |
|---|---|---|
| `bin/voice/voice-door.sh` | `STT` and `STT_MODEL` were resolved before the machine's `~/.config/ymir/voice.env` was read | a machine that named the multilingual `small` model still got the English-only `small.en` |
| `bin/voice/voice-door.sh`, `bin/voice/voice-idle.sh` | `date -Is` is GNU-only | `date: invalid argument 's' for -I` on every host start |
| the host start | it raises the engine with `systemd-run`, which a Mac does not have | covered by the launchd shim's new `systemd-run` road (PR #779) |

## What changed

- The speech settings are read after `voice.env`, like the host machine already was.
- Timestamps use `date +%Y-%m-%dT%H:%M:%S%z`, which both `date`s accept.

## Still owed

The host runs with `HF_HUB_OFFLINE=1`, so on a fresh machine the speech models are never fetched and the engine
fails with `LocalEntryNotFoundError`. `--install` should fetch them once, with the network on.

## Also: the arm could not be read on a Mac

`rodd-arm.sh`, `rodd-helm.sh`, `helm-identity.sh` and `lock-ask.sh` read lease fields with `sed "s/.*\b<field>=…"`. `\b` is a GNU extension; BSD sed treats it as a plain `b`, so every field came back empty and `rodd-arm.sh who` said *the lease names no pid* while the lease held one. The fields are now matched with `sed -E "s/(^|.* )<field>=([^ ]*).*/\2/p"`, which both seds read the same way.

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #787

## Also: Rödd keeps an MCP session

`bin/voice/voice_mcp.py` posted `initialize` and then every call without the `Mcp-Session-Id` the server returned, and never sent `notifications/initialized` over HTTP. A streamable-HTTP server refuses that (`Bad Request: Missing session ID`, measured against workspace-mcp). The client now keeps the session id on the server spec, sends it on every later request, sends the initialized notification, and accepts the empty 202 a notification gets.
