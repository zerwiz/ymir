# bridge · 2.1 · 2026-11-21 — one door carries the fallback, and only llama.cpp is local

At the operator's word: every AI call a hosted service makes should go first to a free hosted model,
then to the fleet's own llama.cpp rails over the tailnet, because *"we don't know what machine are off
or on"*, and *"only use llama. no ollama or lm studio."*

## What was wrong

Bifrost (`.agents/backend/model-bridge.py`) served **one** provider. When that provider was down, rate
limited or refusing, every caller got the error. Each hosted service then kept its own opinion of a
model address, so there was no single place to add a fallback. The door still listed LM Studio as a
provider, and several helpers still recognised LM Studio or ollama as a local road.

## What changed

- **A `chain` provider.** When the home carries `config/model-chain.json` (or `YMIR_MODEL_CHAIN` names a
  file), the door serves the chain with nothing named. A request goes to the first healthy step. A step
  that is down, times out, answers 429/401/403/5xx, or answers 200 with an error and no answer is
  passed over and marked down for `YMIR_CHAIN_HEALTH_TTL` seconds (default 30). Health is probed with
  `GET <base>/models`, bounded to 3 s, and cached. The log names the step that answered and every step
  passed over; each reply carries `X-Ymir-Chain-Step`; `GET /chain` and `--chain` show the steps.
- **Addresses come from the home.** A llama.cpp step names a fleet host, and the door reads its
  `tailnet` (else `lan`) from the fleet registry. `bifrost-bridge.sh` now exports the settings and data
  shelves so the bridge reads them from the home, never from a guess.
- **Two new providers:** `openrouter` (a second hosted gateway, key through env, vault or pi's
  `auth.json`) and `llamacpp` (a rail on another machine).
- **LM Studio is gone as a provider** of the door, the env examples, the provider detector
  (`bin/model/models-detect.sh`, which also stops detecting ollama) and the local-provider heuristics
  (spawn, dispatch, resolve, seat, harness, lock, pretool check). The local-model evaluation test now
  talks to the llama.cpp rail's OpenAI API instead of ollama's.
- **The docs follow:** the local-models asset (`.agents/skills/galdr-ymirsystem/assets/local-models.md`)
  now says only llama.cpp is a local road and drops LM Studio and ollama from detection, choice and
  documentation; the models runbook drops `lmstudio` from `local_providers`.
- **Kept, on purpose:** `docs/features/bilskirnir-choose-a-model.md` (lines 35 and 75) still lists the
  ports Bilskirnir scans, because it describes that app's current default (`BILSKIRNIR_LOCAL_PORTS`),
  whose code now lives in its own repository; that default changes there first, then this page. The
  local-models asset still *names* the two engines once, so galdr can recognise one found on a seat and
  report it for removal. And the usage counters in Hlidskjalf still recognise `lmstudio`/`ollama` in *old*
  usage records, so history is classified correctly (a detector, not a road); and the dated prose that
  records the retirement stays as the record (RULES/06).

## Proof

- `bin/bridge/tests/test_bifrost_chain.sh` — four fake upstreams, two named by fleet host, forced down in
  turn (429, stopped, 200-with-error, all down), plus the cached skip, a streamed reply and no key in
  the output: 14 passed.
- `bin/bridge/tests/test_bifrost_provider.sh` (10 ok) and `.agents/tests/hnoss-model-door.test.sh`
  (PASS), both retargeted off LM Studio.
- The inventory of every caller is `docs/reference/ai-callers.md`; the named half is in the home.

## Measured on the real steps (same day)

A throwaway door on a spare port read the home's chain, and steps were forced down by pointing them at a
closed port. All up: **beam-free answered**. Step 1 down: **the first machine's rail answered**. Steps 1–2
down: **the second machine's rail answered**. Steps 1–3 down: the second hosted gateway was at first
*skipped*, because its model list took longer than the 3 s probe. So two things were added: a per-step
`probe_timeout` (default 10 s, after the hosted gateways were measured at 6–8 s), and a **last-ditch pass**. When the health check skips every step, each step
is asked once more before the door answers 503, and the log names it `(last ditch)`. With both, the
fourth step answered. The fake proof gained case 9 for the last ditch: 16 passed.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #864
