# How llama-swap works — research notes

Research doc for **llama-swap** (mostlygeek/llama-swap) — the external Go
orchestrator that hot-swaps local LLM backends in front of an OpenAI/Anthropic
compatible server. Compiled 2026-09-07 from online sources (GitHub README +
wiki/DeepWiki + hands-on write-ups). Companion to
[`TESTING.md`](./TESTING.md) and §12.5 of [`../backends-benchmark.md`](../backends-benchmark.md).

- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- Status: **research** — llama-swap is a candidate, NOT installed/built yet.
  Native llama.cpp router mode remains the preferred option (§12.5 ranking).

---

## 1. The problem llama-swap solves

Raw `llama-server` has a **one-model-per-process** rule. Serving a second model
meant either a second server on a second port (client-side juggling, manual
VRAM arithmetic) or hand-rolled stop/start scripts. llama-swap removes the
client-side chore: **one stable endpoint, switch models by changing the
`"model"` field in the API request.**

This matches the WayOf requirement exactly:

> "if I swap model in pi.dev / opencode etc., that should STOP the model that's
> running and START the model I chose."

With a proxy/router in front, the client points at one URL; when the client
changes the model, the router stops the old backend and starts the new one —
no manual `model-host start X`.

---

## 2. How it works — the core mechanism

llama-swap is a **lightweight single Go binary** that sits *in front of* your
backends (llama-server, vLLM, tabbyAPI, etc.). It is NOT an inference engine.

```
client (pi.dev / opencode) ──> llama-swap (one port, e.g. :8080)
                                   │  inspects "model" field of each request
                                   ├──> spawns llama-server A (model-a.gguf)
                                   ├──> spawns llama-server B (model-b.gguf)
                                   └──> routes request to the matching backend
```

1. A request arrives on the single endpoint carrying a `"model"` value.
2. llama-swap looks up that model ID in its YAML config.
3. If the right backend is already running → route to it.
4. If the **wrong** backend is running → **stop it**, start the requested one,
   then route. This is the "swap".
5. Optionally unload idle models after a TTL to free VRAM.

The whole thing is controlled by a single YAML file; no code changes needed to
add a model — just add a block.

---

## 3. Minimal configuration

```yaml
# config.yaml
models:
  "smollm2":
    cmd: |
      llama-server --model /models/smollm2.Q4_K_M.gguf --port ${PORT}
  "qwen2.5":
    cmd: |
      llama-server --model /models/qwen2.5.Q4_K_M.gguf --port ${PORT}
```

- `models:` — flat map; the key is the model ID used in API calls.
- `cmd:` — the shell command to run the backend server.
- `${PORT}` — macro; llama-swap auto-assigns a free port to each backend so you
  never hard-code conflicting ports.

Run it:

```bash
llama-swap --config config.yaml --listen 127.0.0.1:8080
```

Start with **no models loaded**; the first request loads the requested model.

Then use it like a normal OpenAI endpoint:

```bash
curl -s http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{ "model": "qwen2.5",
        "messages": [{"role":"user","content":"Hi"}] }'
```

Change `"model"` → llama-swap swaps the backend for you.

---

## 4. Key features

| Feature | What it does |
|---|---|
| On-demand swap | Loads/stops backends on the `model` field, per request |
| **Groups** | Run several models at once (e.g. a "heavy" group with `swap: false`) |
| **TTL** | Idle-unload a model after a timeout → frees VRAM automatically |
| `unloadTimeout` | Graceful unload (manual, API, or TTL expiry) |
| `aliases` | Map a friendly name (e.g. `gpt-4o-mini`) to a real model |
| `hooks` | Run scripts on startup |
| `macros` | Reusable YAML snippets |
| `${PORT}` | Automatic per-backend port assignment |
| `filters` | Rewrite parts of requests before forwarding |
| Web UI | Monitor logs and swap status in a browser |
| Backends | Any OpenAI/Anthropic compatible server: llama.cpp, vLLM, tabbyAPI, etc. |

---

## 5. Groups — the swap control that matters

By default llama-swap allows **one model at a time** (it unloads others when
switching). The `groups` feature changes that:

```yaml
groups:
  heavy:
    models: [qwen3.8-27b, qwen3.6-35b]   # only one resident at a time
    swap: true                            # default: one member loaded at once
  parallel:
    models: [9b-coder, 4b-chat]
    swap: false                           # all members can run concurrently
```

This maps directly onto the WayOf split:
- **swap group** (big models that can't coexist on 16 GB) → `swap: true`
- **parallel group** (small models that fit together) → `swap: false`

---

## 6. llama-swap vs native llama.cpp router mode

llama.cpp shipped **native router mode** (Dec 2025, mature by Aug 2026). Both
do on-demand model switching via the `model` field. Differences:

| Aspect | llama.cpp router mode (native) | llama-swap (external Go proxy) |
|---|---|---|
| Extra process | No — one server owns the port | Yes — a proxy in front of backends |
| Engine support | llama.cpp only | Any OpenAI-compatible (vLLM, etc.) |
| Isolation | Each model = child process | Each model = child process |
| Residency limit | `--models-max` (default 4) | per group (YAML) |
| Idle unload | `--sleep-idle-seconds` | TTL |
| Config | INI preset (`--models-preset`) | YAML |
| Maturity | Experimental; flags shift | Stable, widely used |

Native router mode: start `llama-server` **without `-m`**, with
`--models-dir` or `--models-preset models.ini` and `--models-max 1` on a
single GPU (so a second model evicts rather than silently spilling to RAM).

llama-swap earns its place when you mix engines (llama.cpp + vLLM) or want the
stability of the YAML-driven proxy. For a pure llama.cpp home lab, native
router mode is the cleaner, one-process answer.

---

## 7. Where the adopted system lives (NOT in this skill)

The operative system this research fed — `llama-router`, `model-host`,
`llama-menu`, `swap-proxy`, the registry `llama-models.yaml`, the router INI —
is **machine property, not skill property**. It lives on the serving host:

| Thing | Path |
|---|---|
| Registry (single source of truth) | `~/.local/share/llama-router/scripts/llama-models.yaml` |
| Launcher / engine | `~/.local/share/llama-router/scripts/model-host.sh` |
| Router (+ INI generator) | `~/.local/share/llama-router/scripts/llama-router`, `~/.local/share/llama-router/scripts/gen-llama-router-config.py` |
| TUI | `~/.local/share/llama-router/scripts/llama-menu` |
| Gateway | `~/.local/share/llama-router/scripts/swap-proxy.cjs` |
| System docs | `~/.local/share/llama-router/docs/llama-router/`, `~/.local/share/llama-router/docs/LLAMA_CPP_SERVER.md` |
| Router config snapshot | `~/.local/share/llama-router/config/llama-router-config.json` |

To add or operate a model, edit the registry **on the machine** and run
`model-host verify` — never carry the model table inside a skill. This skill
keeps only the bench method and its results (sections 1-6, `TESTING.md`,
`backends-benchmark.md`).

---

## 8. Sources

- github.com/mostlygeek/llama-swap — README, wiki, config overview
- DeepWiki: mostlygeek/llama-swap — multi-model scenarios, groups, matrix
- runaihome.com — llama.cpp router mode in 2026 (setup, `--models-max 1`, VRAM traps)
- DeepWiki: ggml-org/llama.cpp — router mode & model management
- kdnuggets.com — running multiple LLMs locally with llama-swap (groups, swap:false)

## Related

- [`TESTING.md`](./TESTING.md) — when/whether to actually test llama-swap
- [`../llamacpp/TESTING.md`](../llamacpp/TESTING.md) — the CUDA `llama-server` build it would wrap
- [`../backends-benchmark.md`](../backends-benchmark.md) — §12.5 model-switching services table & ranking
