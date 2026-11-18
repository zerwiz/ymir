# skirnir · 2026-11-12 — the model chain, carried from the pin to main

**Status:** done on branch `eindri/pin-edits-to-main`.

**In three sentences.** On 2026-11-09 Skírnir's model chain was written by hand on the pinned runtime
(`~/ymir-runtime`), not on main, so Gróa could not move the pin without losing it. The Allfather's word
that night was *"give him the mtp model here and the q2 qwen3.6 on nidavellir"*: one model is one point of
silence, so a second must answer when the first does not. This change ports that intent onto main as it
stands today, so the pin's hand edit can be discarded when Gróa next moves it.

## What changed

| Piece | What it does |
|---|---|
| `_model_chain(model)` | Returns the ordered list of (alias, chat URL): the primary, then the fallback. |
| `_rail(...)` | Walks the chain and returns the first answer; returns `None` when every model is silent or none is configured. |
| `_rail_one(...)` | The old single call, now taking the URL it should call. |
| `_chat_url(base)` | Makes a rail base URL into its chat door, the same way `_model_url` does. |

## How it differs from the hand edit

The pin's version read `SKIRNIR_MODEL` again inside the chain. On main the primary is already resolved by
`configured_mouth` (flag, then `SKIRNIR_MODEL`, then `model:` in `skirnir.yaml`), so the chain takes that
resolved model instead of reading the environment a second time. The fallback is read from
`SKIRNIR_MODEL_FALLBACK` and `SKIRNIR_MODEL_FALLBACK_URL`, and also from `model_fallback:` and
`model_fallback_url:` in his config, to match how main already reads the primary (Rule 07).

## The other three hand edits on the pin

They needed no code here, because main already carries them in a later form:

- `apps/rodd/src/main.js` — the Ansuz window icon and the arm-holder lines are on main, and main names
  the arm door through `ARM_DOOR` rather than a hardcoded home path.
- `bin/voice/voice-door.sh` — the microphone ward is on main, and main also excludes Rödd's own window.
- `systems/snotra/services/cron/snotra-cron.sh` — the clickable digest is on main through
  `bin/notify/open-target.sh` (plan 230), which subsumes the inline `notify-send --action` fix.

## How it was checked

`systems/skirnir/services/test_model_chain.py` replaces `urlopen` and proves three things: the primary
answers and the fallback is never asked; the primary fails and the fallback answers behind its own door;
no model configured sends nothing and returns `None`. The whole Skírnir suite passes
(`python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'`, 51 tests).

## CHANGE LOG

- 2026-11-12 — written with the fix.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
