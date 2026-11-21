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
- **Kept, on purpose:** the usage counters in Hlidskjalf still recognise `lmstudio`/`ollama` in *old*
  usage records, so history is classified correctly (a detector, not a road); and the dated prose that
  records the retirement stays as the record (RULES/06).

## Proof

- `bin/bridge/tests/test_bifrost_chain.sh` — four fake upstreams, two named by fleet host, forced down in
  turn (429, stopped, 200-with-error, all down), plus the cached skip, a streamed reply and no key in
  the output: 14 passed.
- `bin/bridge/tests/test_bifrost_provider.sh` (10 ok) and `.agents/tests/hnoss-model-door.test.sh`
  (PASS), both retargeted off LM Studio.
- The inventory of every caller is `docs/reference/ai-callers.md`; the named half is in the home.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #864
