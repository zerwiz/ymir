# llama.cpp Model Host — Complete System Documentation

**Machine**: zerwiz (RTX A5000 16 GB VRAM, 16 cores, 122 GiB RAM)  
**Status**: Working auto-swap via `swap-proxy` + `model-host` engine (2026-09-08)  
**Single Source of Truth**: `scripts/llama-models.yaml` (42 launch ids → 22 unique full names)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SINGLE ENDPOINT :8090                         │
│                    swap-proxy.cjs (auto-swap gateway)                │
│  • Reads: llama-models.yaml (registry) + ~/.pi/agent/models.json    │
│  • On request: resolves model → model-host start <swap-id>          │
│  • Waits for model port → forwards request                           │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
         ┌─────────┐      ┌─────────┐      ┌─────────┐
         │ :8081   │      │ :8088   │      │ :8125   │
         │ qwen9b  │      │ gemma12b│      │ qwen35b │
         │ swap    │      │ swap    │      │ swap    │
         └────┬────┘      └────┬────┘      └────┬────┘
              │                │                │
              └────────────────┼────────────────┘
                               ▼
                    ┌────────────────────────┐
                    │   model-host.sh        │
                    │   (THE ENGINE)         │
                    │ • swap rule: stops     │
                    │   ALL other models     │
                    │ • builds flags from    │
                    │   llama-models.yaml    │
                    │ • launches via         │
                    │   llama-run.sh         │
                    └────────────────────────┘
```

**Key principle**: ONE model at a time on GPU (swap rule). Exception: dual-chat on :8098 (parallel:2, dedicated).

---

## 2. Start / Stop / Status

```bash
# Start auto-swap gateway (port 8090)
scripts/swap-proxy.cjs --port 8090 &
# or use launcher
./scripts/swap-proxy start

# Check status
curl -s http://127.0.0.1:8090/v1/models | jq '.data | length'

# Stop gateway
./scripts/swap-proxy stop

# Test model-host directly (bypasses proxy)
model-host start 9b-swap      # loads on :8081
model-host status
model-host stop               # unloads everything

# dual-chat (dedicated, always resident)
model-host start dualchat-gemma   # :8098, parallel:2
```

---

## 3. The 22 Models (Full Names + Ports)

| # | Full Name (use this in `model` field) | Swap Port | Launch Command | Context | Reasoning |
|---|---|---|---|---|---|
| 1 | `qwen3.6-35b-a3b@q2_k_xl` | 8125 | `model-host start q2-swap` | 155904 | no |
| 2 | `qwen3.6-35b-a3b@iq3_s` | 8125 | `model-host start iq3-swap` | 100000 | no |
| 3 | `qwen3.6-35b-a3b@q4_k_s` | 8125 | `model-host start q4-swap` | 120000 | no |
| 4 | `qwen3.6-35b-a3b@q5_k_m` | 8125 | `model-host start q5-swap` | 120000 | no |
| 5 | `qwen3.6-35b-a3b@iq3_s-orch` | 8093 | `model-host start q3` | 100000 | **yes** |
| 6 | `qwen3.5-9b@q4_k_s` | 8081 | `model-host start 9b-swap` | 262144 | **yes** |
| 7 | `qwen3.5-9b-highctx@q4_k_s` | 8081 | `model-host start 9b-highctx-swap` | 262144 | **yes** |
| 8 | `qwen3.5-4b@q4_k_s` | 8084 | `model-host start 4b-swap` | 262144 | **yes** |
| 9 | `qwen3.5-9b-uncensored@q4_k_m` | 8081 | `model-host start hauhau-9b-swap` | 262144 | **yes** |
| 10 | `qwen3.8-27b@q3_k_xl` | 8083 | `model-host start 27b-swap` | 100000 | **yes** |
| 11 | `qwen3.8-27b-cpu@q3_k_xl` | 8083 | `model-host start 27b-cpu-swap` | 120000 | **yes** |
| 12 | `qwen3.8-flash-next@q3_k_xl` | 8095 | `model-host start q3-flash-swap` | 100000 | **yes** |
| 13 | `qwopus3.5-9b-coder@q8_0` | 8086 | `model-host start qwopus-swap` | 131072 | **yes** |
| 14 | `frontend-design-expert-8b@q4_k_m` | 8087 | `model-host start frontend-swap` | 100000 | no |
| 15 | `gemma-4-26b-a4b@q5_k_xl` | 8085 | `model-host start gemma-swap` | 120000 | no |
| 16 | `gemma-4-12b@q3_k_s` | 8088 | `model-host start 12b-q3-swap` | 131072 | no |
| 17 | `gemma-4-12b@q4_k_m` | 8088 | `model-host start 12b-q4-swap` | 131072 | no |
| 18 | `gemma4-12b-qat-uncensored@q4_k_m` | 8088 | `model-host start hauhau-gemma-swap` | 131072 | no |
| 19 | `gemma4-12b-qat-uncensored@dual-chat` | 8098 | `model-host start dualchat-gemma` | 131072 | no |
| 20 | `minicpm5-1b-agentic-tooluse@q8_0` | 8092 | `model-host start minicpm-swap` | 131072 | no |
| 21 | `nomic-embed-text-v1.5@embed` | 8100 | `model-host start embed-swap` | 8192 | no |
| 22 | `gpt-oss-20b@f16` | 8096 | `model-host start gptoss20b-swap` | 100000 | no |

---

## 4. Client Connection Configs

### 4.1 opencode (all 4 accounts)

Each account needs a `llama.cpp` provider pointing at the swap-proxy:

```json
{
  "provider": "llama.cpp",
  "baseURL": "http://127.0.0.1:8090/v1",
  "apiKey": "sk-not-key-required",
  "models": ["auto"]  // opencode will fetch /v1/models
}
```

**Config locations**:
- `~/.config/opencode/opencode.json`
- `~/.config/opencode-rd/opencode.json`
- `~/.config/opencode-work/opencode.json`
- `~/.config/opencode-oczer/opencode.json`

After adding, run `/login llama.cpp` in opencode — it will fetch all 64 models from `:8090/v1/models`.

---

### 4.2 Zed IDE

```json
{
  "language_models": {
    "llama.cpp": {
      "auto_discover": true,
      "base_url": "http://127.0.0.1:8090/v1",
      "api_key": "sk-not-key-required"
    }
  }
}
```

**Location**: `~/.config/zed/settings.json`

`auto_discover: true` pulls all models from `/v1/models`. Zed will show all 64 models in the model picker.

---

### 4.3 pi (the model catalog)

**File**: `~/.pi/agent/models.json` (mirror: `~/command/.pi/models.json`)

pi uses per-model providers with `_launchCommand`. Already fixed to 22 full-name providers:

```json
{
  "providers": {
    "llamacpp-qwen3-6-35b-a3b-q2_k_xl": {
      "api": "openai-completions",
      "apiKey": "sk-not-key-required",
      "baseUrl": "http://127.0.0.1:8125/v1",
      "models": [{
        "id": "qwen3.6-35b-a3b@q2_k_xl",
        "name": "qwen3.6-35b-a3b@q2_k_xl (llama.cpp :8125)",
        "input": ["text"],
        "contextWindow": 155904,
        "reasoning": false,
        "_launch": true,
        "_launchCommand": "model-host start q2-swap",
        "_notes": "swap variant; port/ctx from llama-models.yaml 2026-09-08"
      }]
    },
    ...
  }
}
```

**pi workflow**: When you select a model in pi, it runs `_launchCommand` (`model-host start <swap-id>`), waits for the model to load on its port, then sends requests to that model's direct port. Auto-switch handled by pi itself.

---

### 4.4 Direct API (curl / custom clients)

```bash
# List models
curl http://127.0.0.1:8090/v1/models

# Chat completion (auto-swaps)
curl -X POST http://127.0.0.1:8090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.5-9b@q4_k_s",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'

# Embeddings
curl -X POST http://127.0.0.1:8090/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text-v1.5@embed",
    "input": "text to embed"
  }'
```

---

### 4.5 Other OpenAI-compatible clients

Any client that speaks OpenAI API format:

```json
{
  "base_url": "http://127.0.0.1:8090/v1",
  "api_key": "sk-not-key-required",
  "model": "qwen3.5-9b@q4_k_s"   // or any full name from the table
}
```

---

## 5. Model Tuning (from TESTING.md)

Models are tuned for RTX A5000 16 GB. Key flags in `llama-models.yaml`:

| Model Family | Quant | Offload Strategy | Key Flags |
|---|---|---|---|
| **Qwen3.6-35B-A3B** (MoE) | Q2/IQ3 | pure GPU | `--n-cpu-moe 0` |
| | Q4 | partial expert offload | `--n-cpu-moe 18` |
| | Q5 | partial expert offload | `--n-cpu-moe 22` |
| **Qwen3.8-Flash-Next** (125B MoE) | Q3 | all experts CPU | `--n-cpu-moe 999 --threads 16` |
| **Gemma-4-26B-A4B** (MoE) | Q5_K_XL | partial offload | `--n-cpu-moe 20 --cache-type-k/v q4_0` |
| **Qwen3.8-27B** (dense) | Q3_K_XL | pure GPU + KV quant | `--ngl 999 --cache-type-k/v iq4_nl` |
| **27B CPU** | Q3_K_XL | pure CPU | `--ngl 0` |
| **All others** | various | pure GPU | `--ngl 999` |

**Embeddings**: Nomic Embed on :8100 (`--embedding` mode, 768-dim, ~0.1s)

---

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| `Connection refused` on :8090 | `scripts/swap-proxy start` or `node scripts/swap-proxy.cjs --port 8090 &` |
| Model fails to load (OOM) | `model-host stop` — another model holding VRAM; swap rule should auto-unload |
| `/v1/models` returns few models | Check swap-proxy log: `cat /tmp/opencode/swap-proxy.log` |
| pi shows old models | Rebuild `~/.pi/agent/models.json` per §4.3 (22 full-name providers) |
| Zed doesn't discover models | Ensure `auto_discover: true` and Zed can reach `127.0.0.1:8090` |
| opencode `/login` fails | Check opencode provider `baseURL` = `http://127.0.0.1:8090/v1` |
| dual-chat `Loading model` error | Must use dedicated `dualchat` provider → :8098, NOT swap-proxy |

---

## 7. Ports Summary

| Port | Service | Notes |
|---|---|---|
| **8090** | **swap-proxy** (main gateway) | All clients → here |
| 8081 | qwen9b swap group (9b, 9b-highctx, hauhau-9b) | |
| 8083 | qwen27b swap group (27b, 27b-cpu) | |
| 8084 | qwen4b swap group | |
| 8085 | gemma26b swap | |
| 8086 | qwopus9b swap | |
| 8087 | frontend8b swap | |
| 8088 | gemma12b swap group (3 models) | |
| 8089 | 12b-q4 parallel (dedicated port) | |
| 8092 | minicpm1b swap | |
| 8093 | q3 orchestrator | |
| 8094 | 27b-cpu parallel | |
| 8095 | q3-flash swap | |
| 8096 | gptoss20b swap | |
| 8098 | **dual-chat dedicated** (parallel:2) | Do not route through swap-proxy |
| 8100 | embeddings swap | |
| 8125 | qwen35b swap group (4 quants) | |
| 8126 | iq3 parallel | |
| 8127 | q4 parallel | |
| 8128 | q5 parallel | |

---

## 8. Key Files

| File | Role |
|---|---|
| `scripts/llama-models.yaml` | Registry (single source of truth) |
| `scripts/model-host.sh` | Engine (start/stop/status/verify) |
| `scripts/llama-run.sh` | Detached llama-server wrapper |
| `scripts/swap-proxy.cjs` | Auto-swap gateway (:8090) |
| `~/.local/bin/llama-models` | CLI for registry (`list`, `get`, `ids`, `ports`) |
| `~/.pi/agent/models.json` | Pi's catalog (22 full-name providers) |
| `~/.config/llama-containers/llama-menu` | TUI controller (doubled-letter keys) |

---

## 9. Config File Locations (Exact Paths)

| Client | Config File |
|---|---|
| **opencode (main)** | `/home/zerwiz/.config/opencode/opencode.json` |
| **opencode-rd** | `/home/zerwiz/.config/opencode-rd/opencode.json` |
| **opencode-work** | `/home/zerwiz/.config/opencode-work/opencode.json` |
| **opencode-oczer** | `/home/zerwiz/.config/opencode-oczer/opencode.json` |
| **Zed IDE** | `/home/zerwiz/.config/zed/settings.json` |
| **pi (model catalog)** | `/home/zerwiz/.pi/agent/models.json` |
| **pi mirror (repo)** | `/home/zerwiz/command/.pi/models.json` |

---

## 9. Quick Start Checklist

```bash
# 1. Start gateway
./scripts/swap-proxy start

# 2. Verify
curl -s http://127.0.0.1:8090/v1/models | jq '.data | length'
# → 64

# 3. Test swap
curl -s -X POST http://127.0.0.1:8090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"minicpm5-1b-agentic-tooluse@q8_0","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'

# 4. Configure clients (opencode, Zed, pi) per §4

# 5. For dual-chat
model-host start dualchat-gemma
```

---

## 10. Adding a New Model

1. Bench it first (`modeltesting` skill, `llamacpp/TESTING.md` §10 checklist)
2. Add YAML block to `scripts/llama-models.yaml` (pick free port, correct flags)
3. `model-host verify` — must pass
4. `model-host start <new-id>` — test loads
5. Gateway picks it up on restart (or add pi provider manually)
5. Update `contextWindow` in pi's models.json after bench
---

## 11. Two Serving Paths — Why Zed on 8080, opencode/pi on 8090

There are **two working paths** built from the same registry (`llama-models.yaml`):

| Path | Port | For | How it works |
|---|---|---|---|
| **Native Router** | **8080** | **Zed IDE** | `llama-router start` → generates `models.ini` (22 full-name presets) → `llama-server --models-preset --models-max 1`. Zed `auto_discover: true` pulls all models. On request, router loads model, evicts previous (`--models-max 1`). |
| **Swap-Proxy + model-host** | **8090** | **opencode, pi, direct API** | `swap-proxy.cjs` reads registry + pi models.json. On request, resolves model → `model-host start <swap-id>` → waits for port → forwards. model-host enforces swap rule (stops all others first). |

### Start Both (recommended)

```bash
# Terminal 1: Native router for Zed (port 8080)
pkill -f "llama serve"
llama-router start

# Terminal 2: Swap-proxy for opencode/pi (port 8090)
node /home/zerwiz/command/scripts/swap-proxy.cjs --port 8090 &
# or use launcher: ./scripts/swap-proxy start
```

### Client Wiring

| Client | Base URL | Config |
|---|---|---|
| **Zed IDE** | `http://127.0.0.1:8080/v1` | `auto_discover: true` in `~/.config/zed/settings.json` |
| **opencode (×4)** | `http://127.0.0.1:8090/v1` | provider `llama.cpp` in each `opencode.json` |
| **pi** | per-model direct ports (8081, 8083, 8088, etc.) | `_launchCommand: model-host start <swap-id>` in `~/.pi/agent/models.json` |
| **Direct API** | `http://127.0.0.1:8090/v1` | any OpenAI-compatible client |

### Why Not Just One?

- **Router (8080)** is the "blessed" native path — Zed's `auto_discover` expects the router's `/v1/models` format. Works out of the box.
- **Swap-proxy (8090)** keeps `model-host` as the engine (user's working path from yesterday) and gives pi/opencode the exact same model IDs + auto-switch behavior via the same launcher.
- Both read from the **same registry** (`llama-models.yaml`). Single source of truth.

### Don't Use Bare `llama serve`

Bare `llama serve` starts the router **without a preset** → only serves 1 cached model (the bge-small embed). Always use `llama-router start` which regenerates the INI.

---

## 12. Verified Working Commands

```bash
# 1. Start router for Zed
pkill -f "llama serve"
llama-router start
# → /tmp/opencode/llama-models.ini generated (22 models)
# → llama-server --models-preset --models-max 1 --port 8080

# 2. Start swap-proxy for opencode/pi
./scripts/swap-proxy start
# OR: node scripts/swap-proxy.cjs --port 8090 &

# 3. Verify both
curl -s http://127.0.0.1:8080/v1/models | jq '.data | length'   # → 22
curl -s http://127.0.0.1:8090/v1/models | jq '.data | length'   # → 64 (registry + pi)

# 4. Test Zed path (router auto-load)
curl -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.5-9b@q4_k_s","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'

# 5. Test opencode/pi path (swap-proxy auto-swap)
curl -X POST http://127.0.0.1:8090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"minicpm5-1b-agentic-tooluse@q8_0","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'
```

---

## 13. Connecting Unsloth Desktop

Unsloth Desktop can connect to any **OpenAI-compatible** endpoint. It supports llama.cpp, vLLM, Ollama, etc.

### Which endpoint to use?

| Option | URL | Models | Notes |
|---|---|---|---|
| **Native Router (recommended)** | `http://127.0.0.1:8080/v1` | 22 full-name models | Standard llama.cpp router, same as Zed |
| **Swap-Proxy** | `http://127.0.0.1:8090/v1` | 64 models (registry + pi) | Includes pi full-name variants |

**Use 8080** for simplicity — it's the native llama.cpp router.

### Setup in Unsloth Desktop

1. Open **Unsloth Desktop** → **Settings** (gear icon) → **Connections**
2. Click **Add Connection**
3. Select **llama.cpp** (or "OpenAI Compatible")
4. Enter:
   - **Base URL**: `http://127.0.0.1:8080/v1`
   - **API Key**: leave empty (or `sk-not-key-required` if required)
5. Click **Load Models** — Unsloth will fetch `/v1/models`
6. Enable desired models
7. Models now appear under **Connected** in the model selector dropdown

### Requirements

- **Router must be running**: `llama-router start` (generates INI, starts 22-model router on 8080)
- If router not running, Unsloth will show connection error

### For Swap-Proxy (if you want pi variants too)

Same steps, but URL: `http://127.0.0.1:8090/v1` (requires `./scripts/swap-proxy start`)

### Troubleshooting

| Error | Fix |
|---|---|
| `tcp connect error` / connection refused | Start router: `llama-router start` |
| Models don't load | Check router log: `cat /tmp/opencode/llama-router.log` |
| "Cannot read clipboard" | Unrelated — clipboard permission issue in Unsloth |

### Quick Test Before Connecting

```bash
curl -s http://127.0.0.1:8080/v1/models | jq '.data | length'
# should return 22+
```

---

## 14. Unsloth Desktop — Verified Working (2026-09-08)

**Status**: ✅ Works with native router on port 8080.

### Quick Setup

```bash
# Ensure router is running (required!)
llama-router start
# or if dead: pkill -f "llama serve" && llama-router start
```

In **Unsloth Desktop**:
1. Settings → Connections → **Add Connection**
2. Select **llama.cpp**
3. **Base URL**: `http://127.0.0.1:8080/v1`
4. **API Key**: (leave empty)
5. Click **Load Models** → fetches 23 models from `/v1/models`
6. Enable desired models → appear in **Connected** dropdown

### Verified Models (from router)

```
qwen3.5-9b@q4_k_s
qwen3.5-9b-highctx@q4_k_s
qwen3.5-9b-uncensored@q4_k_m
qwen3.5-4b@q4_k_s
qwen3.6-35b-a3b@q2_k_xl
qwen3.6-35b-a3b@iq3_s
qwen3.6-35b-a3b@q4_k_s
qwen3.6-35b-a3b@q5_k_m
qwen3.6-35b-a3b@iq3_s-orch
qwen3.8-27b@q3_k_xl
qwen3.8-27b-cpu@q3_k_xl
qwen3.8-flash-next@q3_k_xl
qwopus3.5-9b-coder@q8_0
frontend-design-expert-8b@q4_k_m
gemma-4-12b@q3_k_s
gemma-4-12b@q4_k_m
gemma-4-26b-a4b@q5_k_xl
gemma4-12b-qat-uncensored@q4_k_m
gemma4-12b-qat-uncensored@dual-chat
minicpm5-1b-agentic-tooluse@q8_0
nomic-embed-text-v1.5@embed
gpt-oss-20b@f16
unsloth/bge-small-en-v1.5-GGUF:F16  (cached embed)
```

### Common Error: "could not load from llama cpp"

| Cause | Fix |
|---|---|
| Router not running | `llama-router start` |
| Router died | `pkill -f "llama serve" && llama-router start` |
| Wrong port | Use `8080`, not `8090` |
| Firewall/localhost | Ensure `127.0.0.1` not `localhost` (some apps differ) |

### Router Management

```bash
llama-router status        # check
llama-router restart       # regenerate INI + restart
llama-router stop          # stop
```

The router auto-regenerates `/tmp/opencode/llama-models.ini` from `llama-models.yaml` on every start.

---

## 15. Server Commands Reference

**There is no `llama server start/stop` or `llama-server` command.** The `llama` CLI only has `serve` (runs foreground). Use these instead:

| Purpose | Command | Port | Notes |
|---|---|---|---|
| **Native Router (Zed, Unsloth)** | `llama-router start` | 8080 | Generates INI from registry, starts `llama-server --models-preset --models-max 1` |
| | `llama-router stop` | | |
| | `llama-router restart` | | Regenerates INI + restarts |
| | `llama-router status` | | Shows running + model count |
| **Swap-Proxy (opencode, pi)** | `./scripts/swap-proxy start` | 8090 | Reads registry + pi models.json, calls `model-host start` |
| | `./scripts/swap-proxy stop` | | |
| | `./scripts/swap-proxy restart` | | |
| | `./scripts/swap-proxy status` | | |
| **Direct model-host (manual)** | `model-host start <id>` | per-model | Loads one model, stops all others (swap rule) |
| | `model-host stop` | | Stops everything |
| | `model-host status` | | Shows running models |
| | `model-host list` | | Shows all 42 registry entries |
| | `model-host verify` | | Validates registry |
| **TUI Controller** | `llama-menu` | | Interactive menu (doubled-letter keys) |
| **Registry CLI** | `llama-models list` | | Table of all models |
| | `llama-models ids` | | Just the 42 ids |
| | `llama-models get <id> <field>` | | Get ctx, port, gguf, etc. |

### Bare `llama serve` — DO NOT USE

```bash
# This ONLY serves 1 cached model (bge-small embed), NOT the registry
llama serve
```

Always use `llama-router start` which regenerates the preset INI from `llama-models.yaml`.

### Quick Start (both paths)

```bash
# Terminal 1: Router for Zed/Unsloth
llama-router start

# Terminal 2: Swap-proxy for opencode/pi
./scripts/swap-proxy start

# Verify
curl -s http://127.0.0.1:8080/v1/models | jq '.data | length'  # 23
curl -s http://127.0.0.1:8090/v1/models | jq '.data | length'  # 64
```
