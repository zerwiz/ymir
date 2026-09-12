# Runbook — setting up models

Ymir runs each agent on a model you choose. **Local models run through `pi`,
hosted models through `opencode`** — the syncer derives this, you just pick the
model.

## The one place you choose

`config/agents.yaml` (private; from `config/agents.yaml.example`):

```yaml
harness:
  local: pi
  online: opencode
  local_providers: [llama.cpp, llama-cpp, lmstudio]
  providers:
    llama.cpp: { pi: llama-cpp }      # same server, renamed per harness

default_model: opencode-go/deepseek-v4.1-flash

providers:
  llama.cpp:
    npm: "@ai-sdk/openai-compatible"
    name: "llama-server (local)"
    base_url: "http://127.0.0.1:8080/v1"
    models:
      - frontend-design-expert-8b     # bare alias; apply resolves the exact id

agents:
  hnoss: { model: "llama.cpp/frontend-design-expert-8b", primary: true }
  brokk: { model: opencode-go/deepseek-v4.1-flash }
```

## Local models (llama.cpp)

1. Start a server (llama.cpp `llama-server`) — e.g. `:8080`. Check it:
   ```bash
   curl -s http://127.0.0.1:8080/v1/models | head
   ```
2. A llama.cpp **router needs the exact served id**, e.g.
   `frontend-design-expert-8b@q4_k_m`. Put the bare alias in the YAML; `apply`
   asks the server and fills in the exact id.
3. `pi` must know the provider. Verify: `pi --list-models | grep llama`.

## Apply and use

```bash
bin/agents-config.sh init        # seed from template (once)
bin/agents-config.sh resolve     # show bare alias -> exact id
bin/agents-config.sh show        # the live combination (agent, harness, model)
bin/agents-config.sh apply       # write into profiles + opencode.json
bin/agent-run.sh hnoss "design a hero section"
```

## Different models on different machines

Keep a per-machine overlay `config/agents.<hostname>.yaml`; it deep-merges over
the base. Example: `config/agents.machine.example.yaml`. Override the host with
`YMIR_AGENTS_MACHINE=omarchy-1`.

## Hosted models

Add the provider key to `.env.local` (e.g. `OPENCODE_GO_API_KEY`) — never inline
a key. Models named `opencode-go/...` run through `opencode`.

## Adding a model

Add it under `providers.<name>.models` (or a new `providers` entry). If it's a
new server, add the id to `.agents/skills/galdr/assets/registry.md`.
