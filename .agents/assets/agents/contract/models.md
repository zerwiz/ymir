Read when: choosing, routing, adding or naming a model, or reading what a machine can serve.

# Models and providers

Part of the Ymir contract. The prior text, including the original provider tables, is kept verbatim in
`docs/contract-history/AGENTS-2026-11-24.md`.

## Ask the machine, never a document (2026-10-24)

`bin/model/catalog.sh` is the one door to what this box can serve: `pi --list-models` behind a TOON face, across every
provider pi knows (openrouter, llama-swap, opencode-go and the fleet's llama.cpp rails, measured at 496 models over five
providers on 2026-10-24). The resolver, the spawn guard and the session digest all read that door; none keeps a second
table.

| Rule | Why |
|---|---|
| A model the catalog lists is pi's to serve | the harness follows the catalog, not a prose rule |
| opencode-go models are served through pi with that provider | they are in pi's catalog: `bin/model/catalog.sh --has opencode-go/deepseek-v4.1-flash` |
| A model the catalog does not list is a refusal | never a guess, never a silent fallback |

The audit and its evidence are in the home: `hodd/docs/audits/2026-10-24-the-model-knowledge-audited.md`.

## What still holds from the provider era

- Ymir decouples agent logic from model providers. The counsellor (the primary) is a private agent, not routed through
  any provider. Other agents route reasoning through OpenAI-compatible endpoints, chosen with `OPENAI_BASE_URL` and
  `OPENAI_MODEL`; `opencode.json` configures the providers a dispatch may pick from.
- **One local model at a time per router.** A machine cannot serve two large GGUF models at once; swap by re-pointing
  the llama router, or by raising one seat and lowering the other. The default local coding model on the rail is
  `qwen3.6-35b-a3b` behind `http://127.0.0.1:8080/v1`.
- **LM Studio is retired** (*"no lm studio we not using that"*). The old table named it on `:1234`; nothing serves
  there. The model bridge no longer falls back to it: it reads its key through the vault and otherwise serves the local
  rail (plan 275 item 22).
- **Apodex** (`apodex-1.0-mini`, weights `apodex/Apodex-1.0-mini` on Hugging Face) is **Apache 2.0**, and its
  AgentHarness (`ApodexAI/AgentHarness`) is Apache 2.0 with one MIT component; Ymir is Apache 2.0, so there is no licence
  conflict. Validate it with `bin/model/apodex-smoke-test.sh` before routing research through it. Its Q4_K_M weights are
  about 21.7 GB, so it and a coding model cannot both sit resident.
- Local models run in **pi**; hosted models run in **opencode** (`config/agents.yaml`). pi.dev is the primary agent
  harness and drives both online models and the local rail.
