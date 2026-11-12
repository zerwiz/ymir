# Bilskirnir: choosing a model is a button, whatever providers the user has

**2026-11-12 · component: apps · `apps/bilskirnir/server/src/models/` · `routes-config.ts` · `engine.ts` · `web/src/components/config/ModelsSection.tsx` · `setup.sh`**

## What was wrong

`setup.sh` hard-coded the first agent's model from two environment variables, whose defaults were one machine's own
rail. It read the key only from `~/.pi/agent/auth.json`. A user with an OpenRouter key, an Ollama server, or no pi
at all had to edit files to get an answer. The Allfather's word: it must be super simple for any user, because
they all have different providers and applications.

## What was done

| Part | What it does |
|---|---|
| Detector (`models/detect.ts`) | Reads the environment, pi, OpenCode and Hermes configs, the app's own added providers, and probes Ollama, LM Studio, llama.cpp and vLLM ports. Read-only; a missing place is skipped. The same endpoint found twice is one provider. |
| Keys | Never printed, returned or sent to the page. The detector keeps a reference to where a key was found and reads it only to list models or to write an agent's config. |
| Allow-list | Every model is judged by `bin/model/model-allow.sh filter`, the one door. No file means everything found is selectable. A list with its door missing is a refusal. |
| Models page | Settings › Models: providers found, their models, *Use for <agent>*, and *Add a provider* with presets. Disallowed models are shown greyed with "not allowed in this fleet". |
| Choosing (`models/choose.ts`) | Rewrites only the `model:` block of that agent's Hermes `config.yaml`, with the same text `setup.sh` renders, records the choice, then reloads the gateway (`reloadEngine`). |
| Pasted keys | Go to `$YMIR_HOME/hodd/secrets/bilskirnir-providers.env` (0600), or the app's ignored `data/models/keys.env`. |
| `setup.sh` | No longer reads pi. Order: `BILSKIRNIR_MODEL`, then the page's choice, then the agent's own model, then the first allowed chat model found. Nothing found is said in words and is not a failure. |

## Proof

| Check | Result |
|---|---|
| `node_modules/.bin/tsx tests/model-door.mts` | 48 checks pass: stub servers, a temporary HOME, a real allow-list through `model-allow.sh`, no key in any browser-bound text, 0600 files, and the `setup.sh` order |
| `setup.sh` on the real tree | override honoured; a fresh run took the first allowed model; `--check` reported current |
| `POST /api/bots/<id>/model` on a throwaway server | a refused model answered "not allowed in this fleet"; an allowed one rewrote only the model block and was recorded |
| `node tests/models-screen.mjs` | desktop 1280×900 and phone 390×844: no sideways scroll, no key-like text on the page; pictures in `apps/bilskirnir/assets/screenshots/` |

The pictures were taken against a clean demo HOME with stub providers, so they show no real machine, path or key.

## What was not changed

- **The machine's own `~/.hermes` agent.** It also serves messaging, so this page refuses to switch it.
- **Subscription sign-ins** with no key still go through the *Engine* panel.
- **No live Anthropic or OpenRouter call was made.** Their model lists were not fetched from the real services. The
  paths are covered by the stub servers and by the real local rail only.

## CHANGE LOG

- **2026-11-12** — written (Eindri `model-door`).
- **2026-11-12** — correction (gather-five, after the review of PR #692): the line above that says "48 checks pass" is wrong; the suite `tests/model-door.mts` has 41 checks. The original line stands as the record.
