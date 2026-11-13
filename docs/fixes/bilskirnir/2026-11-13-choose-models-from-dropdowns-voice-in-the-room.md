# Bilskirnir: choose local or online models from dropdowns; the key reaches Hermes; spoken lines reach the room

**Status:** built and tested in Bilskirnir's window on heimdall, 2026-11-13 (plan 275), at the Allfather's word:
*"we wanna have simple ways between local and online model switching in the settings"*, *"all models for that
provider come in a dropdown, not so we need to type them out — same for local"*, *"the dropdown for provider can be
outside the window"*, *"the chat I'm having on streaming voice is not getting into the session's chat"*.

## What changed

| Part | Change |
|---|---|
| The engine panel | A Local / Online switch, then a provider dropdown and a model dropdown filled from the house's catalog (`GET /api/models`). Local is this machine's rail and the fleet's rails; online is the hosted providers. Models held back by the fleet's allow-list are counted, not listed. Save uses the catalog door (`POST /bots/:id/model`), which writes the choice into the agent's Hermes home |
| `PickList` | A dropdown drawn inside the page: never wider than the window, never taller than the room left, opens upward when there is no room below. The native select could open off the screen |
| `choose.ts` | Hermes reads a built-in provider's key (opencode go, openrouter, …) only from the agent's `.env` under its own name (`OPENCODE_GO_API_KEY`), ignoring `config.yaml`'s `api_key`; the key is now written there too. Before: "No usable credentials found for provider 'opencode-go'" |
| Voice | Every line of a call, his and the agent's, is written into the room the moment it settles (`POST /api/voice/line`), as a message marked `from: voice` |

## How it was proven (heimdall)

- A Nanna answered "42" in 24 s on `deepseek-v4.1-flash` through opencode go; the graphics card stayed at 3.3 GB.
- In the window: Online listed OpenCode Go (1 allowed model) and OpenRouter; Local listed llama-swap (41), llamacpp-omarchy
  (26) and llamacpp-whynot (5); every list stayed inside the window. A local model was saved and then deepseek again;
  Hermes' `config.yaml` followed both, and the `.env` holds `OPENCODE_GO_API_KEY`.
- A call session from the window: two lines posted, both in the room as voice messages, call ended.
