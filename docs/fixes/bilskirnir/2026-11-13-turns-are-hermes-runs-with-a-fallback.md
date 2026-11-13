# Bilskirnir: every turn is a Hermes run, a lost turn recovers itself, and a failing model falls back

**Status:** built and tested on heimdall and nidavellir, 2026-11-13 (plan 275, wave 1 of
`hodd/docs/research/2026-11-13-hermes-features-for-bilskirnir.md`), at the Allfather's word: *"Okay, continue."*

## What changed

| Part | Change |
|---|---|
| The turn road | A turn is a Hermes run (`POST /v1/runs`, events from `/v1/runs/{id}/events`) instead of `/v1/responses`. The old road stays behind `BILSKIRNIR_TURN_ROAD=responses` |
| One session per conversation | `engine_runs` (bot, generation → Hermes session, last run). A conversation begun on the old road keeps its history: its session is read from the agent's `response_store.db` |
| Stop | Stopping a turn also stops the Hermes run (`/v1/runs/{id}/stop`) |
| A lost turn | When Hermes holds a session behind a turn it lost in a restart, the run road resolves it (`/v1/runs/{id}/resolve-unknown`), or for a turn from the old road discards it (`hermes sessions discard <session> --yes`), and runs the turn once more. The lost input is not replayed |
| Approvals | Hermes' approval requests become the house's approval card; the answer goes back to the run (`/v1/runs/{id}/approval`) |
| Reasoning | The effort is sent nested (`model_options.reasoning.effort`), as Hermes reads it; the flat `reasoning_effort` was ignored, and one bare run on `deepseek-v4.1-flash` reasoned for 45,421 tokens |
| Fallback | An "If it fails" dropdown in the engine panel lists the local models; the choice is written to the agent's `fallback_providers` (`provider: custom`, `base_url`, `key_env`), its key into the agent's `.env` |

## How it was proven

| Test | heimdall | nidavellir |
|---|---|---|
| A question, a question with a tool | "42"; "It's 19:37" with the terminal tool's row | see the plan |
| Stop in the middle of a turn | the room says "Stopped."; Hermes reports the run `cancelled` | see the plan |
| The first Nanna, held since the afternoon by a lost turn | the lost turn discarded, then "42" | — |
| Fallback | online key broken on purpose: "Fallback activated: deepseek-v4.1-flash → qwen3.5-9b-highctx-262k", answer "42"; key restored: "48" on deepseek again | see the plan |

Still owed from wave 1: Hermes' clarifying questions (`/v1/runs/{id}/clarify`) as a card, and a session list per agent.
