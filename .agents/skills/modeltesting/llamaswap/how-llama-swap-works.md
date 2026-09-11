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

## 7. Relevance to the WayOf model-host setup

Current `model-host.sh` is a **manual launcher**: you must run
`model-host start <model>` yourself, and it only swaps models that share the
same **swap group + port**. Two gaps the research highlights:

1. **No automatic stop/start on client model change.** pi.dev/opencode point at
   a fixed URL; changing the model doesn't tell `model-host` to swap.
   → A router/proxy (native router mode **or** llama-swap) is what delivers
   "swap from the client" transparently.
2. **Same-port parallel twin not swapped out.** The parallel variant (empty
   group) on the same port as a swap group was not stopped by the old
   same-group-only logic. Already patched in `model-host.sh` to stop **any**
   model sharing the port.

**Options going forward:**

| Path | Effort | Delivers "swap from client"? |
|---|---|---|
| Keep `model-host.sh` (patched) | Low | No — still manual |
| Native llama.cpp router mode | Medium | ✅ one port, real eviction |
| llama-swap proxy | Medium | ✅ one port, YAML control, multi-engine |

**Recommendation:** for a pure-llama.cpp box, prefer **native router mode**.
Revisit llama-swap only if per-model process isolation from a mixed engine
stack becomes a requirement.

---

## 8. What we're setting up now — auto-swap

Current state (2026-09-07): we are wiring the **auto-swap** behavior so that
changing the model from a client (pi.dev, opencode, etc.) **stops the running
llama.cpp model and starts the one chosen** — no manual `model-host start X`.

### 8.1 The swap rule we're enforcing

> **All swap models MUST SWAP.** A swap-group variant owns its endpoint
> exclusively: starting it stops *any* other model on the same port — including
> the "parallel" twin that shares the port (which has an empty group and so was
> never stopped by the old same-group-only logic).

### 8.2 What changed in `model-host.sh`

The swap stop-loop in `start()` was patched from:

```bash
# OLD: only stop models in the SAME swap group
[ "$(spec "$m" | cut -d'|' -f6)" = "$group" ] && stop_one "$m"
```

to:

```bash
# NEW: stop ANY model sharing the port (group or parallel twin)
[ "$(spec "$m" | cut -d'|' -f5)" = "$port" ] && stop_one "$m"
```

So a swap start reliably frees the shared port before binding the new server.

### 8.3 The `~/.pi/agent/models.json` sync

The llama.cpp providers in pi's registry now point at the **`-swap` launch
variants** so pi launches the swap model (which self-swaps on its port):

- `llamacpp-q3-flash` → `model-host start q3-flash-swap` (Qwen3.8 Flash Next, :8095)
- `llamacpp-27b` → `model-host start 27b-swap` (:8083)
- `llamacpp-27b-cpu` → `model-host start 27b-cpu-swap` (:8083)
- `llamacpp-9b` → `9b-swap`, `llamacpp-4b` → `4b-swap`, etc.

A copy lives at `~/Ymir/.pi/models.json` (gitignored); the live one pi reads
is `~/.pi/agent/models.json`.

### 8.4 Built: real auto-swap proxy (`scripts/swap-proxy.cjs`)

**Status: IMPLEMENTED + VERIFIED (2026-09-07).** A real auto-swap proxy now
exists and is tested end-to-end. It delivers the exact requirement — "swap
model in pi.dev/opencode → stop the running model, start the one I chose".

**How it works:**

- One stable endpoint: `http://127.0.0.1:8090` (`node scripts/swap-proxy.cjs`).
- Model map is built from TWO sources (merged):
  1. the llama.cpp registry (`llama-models.yaml` via the `llama-models` CLI) —
     all 40 native ids;
  2. pi's launchable models (`~/.pi/agent/models.json`) — the 20 @-variants.
  → `/v1/models` serves all **60**; every id routes to `model-host start <id>`.
- On a request naming model M:
  1. If M is already the loaded model on its port → forward (no reload).
  2. Else → call `model-host start <M>`, which **stops ANY running model** (the
     one-at-a-time swap rule) and starts M.
  3. Wait for the port to accept, then forward the request.
- `GET /v1/models` returns the catalog (HTTP 200) so `/login llama.cpp` in
  pi/opencode validates with no API key.

**Launcher:** `scripts/swap-proxy {start|stop|status|restart}` (pid
`/tmp/opencode/swap-proxy.pid`, log `/tmp/opencode/swap-proxy.log`).

**Verified behaviors (RTX A5000, 2026-09-07):**

| Test | Result |
|---|---|
| Request `minicpm5-1b-agentic-tooluse@q8_0` (nothing running) | ✅ auto-started on :8092, served completion |
| Request `gemma-4-12b@q3_k_s` then `gemma-4-12b@q4_k_m` (same port 8088) | ✅ Q3 stopped (old pid killed), Q4 started, served |
| Re-request already-loaded Q4 | ✅ fast path — no reload, no new swap |
| `swap-proxy` start/stop/status launcher | ✅ works |
| One-at-a-time across ports | ✅ pick A → A unloads when B requested (1 llama-server) |
| `GET /v1/models` | ✅ HTTP 200, 60 models (40 registry + 20 pi @-ids) |
| Registry id via gateway (`minicpm-swap`) | ✅ routes + swaps |

**Integration:** RESOLVED — pi and the 4 opencode accounts point at the proxy
`:8090`; pi's `.pi/agent/models.json` holds all 60 launchable models.

---

## 9. Sources

- github.com/mostlygeek/llama-swap — README, wiki, config overview
- DeepWiki: mostlygeek/llama-swap — multi-model scenarios, groups, matrix
- runaihome.com — llama.cpp router mode in 2026 (setup, `--models-max 1`, VRAM traps)
- DeepWiki: ggml-org/llama.cpp — router mode & model management
- kdnuggets.com — running multiple LLMs locally with llama-swap (groups, swap:false)

## Related

- [`TESTING.md`](./TESTING.md) — when/whether to actually test llama-swap
- [`../llamacpp/TESTING.md`](../llamacpp/TESTING.md) — the CUDA `llama-server` build it would wrap
- [`../backends-benchmark.md`](../backends-benchmark.md) — §12.5 model-switching services table & ranking
