# Bilskirnir — choose a model

## What it is

A page in Bilskirnir's settings that finds the model providers you already have and lets you pick one for each agent.
You do not edit a file. You press a button.

Every agent in the hall can have its own model. Nanna might use a local model, while a research agent uses a cloud one.

## What you need

- Bilskirnir installed and running (see [Bilskirnir — the business hall](bilskirnir.md)).
- At least one provider you can reach. Anything that speaks the OpenAI API works: a cloud account, or a server on this
  computer.
- `hermes` on your PATH. Each agent's brain is a Hermes gateway, and this page changes its model.

## Do it

1. Open **Settings** (⌘, or Ctrl+comma) and choose **Models**.
2. If you have more than one agent, pick which one you are choosing for.
3. Press **Use for Nanna** beside a model. The agent's gateway reloads, and the next message goes through the new model.
4. No provider listed, or yours is missing? Under **Add a provider** pick it from the list, paste a key, and press
   **Add and look for its models**. For anything not in the list, choose *Another server* and give its base URL.

## What it looks for

The hall only reads. A place that does not exist is skipped without a word.

| Where | What it finds |
|---|---|
| The environment | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY`, `DEEPSEEK_API_KEY`, `GROQ_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY` and a few more |
| pi | the providers and keys in `~/.pi/agent/auth.json` and `models.json` |
| OpenCode | the providers in its config and `auth.json` |
| Hermes | the model in `~/.hermes/config.yaml` and the keys in its `.env` |
| This computer | servers answering `/v1/models`: Ollama (11434), LM Studio (1234), llama.cpp or llama-swap (8080), vLLM (8000) |
| This page | providers you added here |

The same server found in two places is shown once, with both places named.

## Your keys

> [!IMPORTANT]
> A key is never shown, never sent to the page and never written into the repo. The page shows only *where* a key was
> found, such as `~/.pi/agent/auth.json (openai.key)`.

A key you paste is kept in your own home secrets (`$YMIR_HOME/hodd/secrets/bilskirnir-providers.env`, readable only by
you). With no home, it is kept in the app's ignored `data/models/` folder instead. When you choose a model, its key is
copied into that agent's own Hermes config, which is also readable only by you.

## When your fleet has an allow-list

If `$YMIR_HOME/config/models-allowed.yaml` exists, it rules this page. Only the models it allows, or a live dated
grant, can be chosen. The rest stay visible but greyed, with the words *not allowed in this fleet*.

The judge is `bin/model/model-allow.sh`, the same door every other part of Ymir asks. This page keeps no copy of the
rule. With no allow-list file, everything found can be chosen.

## First start and `setup.sh`

`setup.sh` no longer needs pi. For the first agent it picks the model in this order:

1. `BILSKIRNIR_MODEL`, with `BILSKIRNIR_BASE_URL` if you set it;
2. the model you chose on this page;
3. the model the agent already has;
4. the first allowed chat model the detector finds.

If nothing is found, `setup.sh` says so in one line and the hall still opens. Choose a model on this page.

## Settings

| Setting | Where | Default |
|---|---|---|
| `BILSKIRNIR_MODEL` | the environment, read by `setup.sh` | unset: the order above |
| `BILSKIRNIR_BASE_URL` | the environment, read by `setup.sh` | the endpoint of the provider that lists the model |
| `BILSKIRNIR_LOCAL_PORTS` | the environment | `ollama:11434,lmstudio:1234,llamacpp:8080,vllm:8000` |
| `BILSKIRNIR_MODELS_DIR` | the environment | `apps/bilskirnir/data/models` |

## Limits

- It speaks the OpenAI-compatible API. A provider with another API needs a gateway in front of it.
- A subscription sign-in with no key (a Claude or ChatGPT plan) is not listed here. Use the agent's *Engine* panel for it.
- The agent on the machine's own `~/.hermes` is never changed from here, because it also serves messaging. Only agents
  whose Hermes home is the app's own can be switched.
- Anthropic's models are listed, but Hermes talks to them through its own provider code. If a chosen Claude model does
  not answer, use the *Engine* panel instead.

## If it does not work

- **A provider says "Not answering".** The server is down, or its address is wrong. Start it, then reopen the page.
- **"Needs a key".** The provider answered but wants a key. Add one under *Add a provider*.
- **Every model is greyed.** Your fleet's allow-list does not name them. Edit `models-allowed.yaml` in your home, or ask
  whoever keeps it for a dated grant.
- **The model changed but the agent still answers the old way.** Its gateway did not reload. Run
  `apps/bilskirnir/start.sh --check` and read `data/run/gateway.log`.

## CHANGE LOG

- **2026-11-12** — first written: the detector, the Models page, the allow-list filter and the `setup.sh` order
  (Eindri `model-door`, at the Allfather's word via Hœnir).
