# Bilskirnir's agents answer again: every Hermes home is named by its real path

**Status:** fixed and tested in Bilskirnir's window on heimdall, 2026-11-13 (plan 275).

## What was seen

From 2026-11-12 19:26 Nanna answered every message with "Something went wrong: profile_mismatch"; Marketing joined
her at 13:17 on 2026-11-13. With the gateway refusing, the engine panel showed only "Default" and no provider could be
chosen.

## Why

Hermes ties each conversation to the profile path it was opened under (a binding receipt in `<home>/state.db`), and
refuses a conversation whose receipt names another path. Bilskirnir named the agents' homes through links: the
conversations were opened under `/home/<user>/ymir/apps/bilskirnir/data/engines/<agent>`, and after the releases
came in the homes were named `~/ymir-runtime/…` or `releases/<sha>/…`. Hermes resolves the real path, so every
receipt looked foreign. A gateway started under an old name was also adopted as it was by the next server start.

## What changed

| Part | Change |
|---|---|
| `setup.sh`, `start.sh` | Nanna's home is written and started by its physical path |
| `server/src/env.ts` | Every agent home is the physical path; an empty `HERMES_HOME_PRIMARY` falls back (`||`, not `??`) |
| `server/src/engine.ts` | A running gateway is adopted only when it was started with the home as named now and its receipts are current; otherwise it is stopped and started again |
| `house/hermes-rebind.py` | New: rebinds receipts whose old path leads to the same folder, after a `state.db` backup; `--check` changes nothing. Run before every gateway start |
| `start.sh --stop` | The window is closed through its main process; killing its group at once left an Electron core (13:22:09) |

## How it was proven

In Bilskirnir's window, driven through DevTools: Marketing answered "What is seven times six?" with "42" in 4 seconds.
Nanna's gateway now admits her messages (Hermes log 13:33:03, one model call, no refusal) and her engine panel offers
nine providers. Her replies still echo "profile_mismatch", because her conversation history is full of that error and
the local model copies it; clearing her room is the operator's choice. Lowering Bilskirnir left no new Electron core.
