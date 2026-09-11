# llama-menu — how the model host works (full reference)

Complete operating documentation for the **llama-menu** native CUDA llama.cpp
model-switching host on zerwiz. Covers the architecture, every script, the
swap model, the gateway, and how pi/opencode/dual-chat connect to it.

- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- Status: verified 2026-09-07
- Backup copy of every script: `~/Ymir/docs/zerwizdocs/backupscripts/llama-menu/`

---

## 1. What llama-menu is

A TUI + CLI stack that runs **llama.cpp GGUF models** on the local GPU, one at
a time, with a stable endpoint. It is data-driven: the model list lives in ONE
YAML file and every tool reads from it — adding a model = one YAML block.

```
llama-menu (TUI)          ── reads ──► llama-models.yaml (source of truth)
   │
   └─► model-host.sh (launcher) ──► llama-run.sh (background wrapper) ──► llama-server
   │
   └─► swap-proxy.cjs (gateway :8090) — serves /v1/models + auto-swaps
```

---

## 2. The scripts (each backed up under backupscripts/llama-menu/)

| File | Role |
|---|---|
| **`llama-models.yaml`** | SINGLE SOURCE OF TRUTH. Registry of every model: id, label, gguf path, ctx, port, swap group, offload flags. |
| **`llama-models.py`** (`~/.local/bin/llama-models`) | CLI reader over the YAML: `list`, `get`, `ports`, `ids`, `groups`, `defaults`, `verify`. |
| **`model-host.sh`** | Launcher: `start <id>`, `stop`, `status`, `list`, `log`, `verify`. Enforces the one-at-a-time swap rule. |
| **`llama-run.sh`** | Detached background wrapper around `llama-server`. Logs `== started/== exited code N ==` so crashes are visible. |
| **`llama-menu`** | The interactive TUI (`~/.config/llama-containers/llama-menu`). |
| **`swap-proxy.cjs`** + **`swap-proxy`** | Gateway `:8090`: OpenAI-compatible endpoint that auto-stops the current model and starts the requested one. Serves `/v1/models` from llama-models.yaml. |
| **`pi-models.json`** | Snapshot of `~/.pi/agent/models.json` (pi's catalog wired to these launch commands). |

---

## 3. The registry — `llama-models.yaml`

Every model is one YAML block under `models:`. Key fields:

| Field | Meaning |
|---|---|
| `id` | short CLI/menu key, no spaces (e.g. `9b-swap`) |
| `label` | human name shown in the menu |
| `gguf` | GGUF path relative to `models_dir` (`/home/zerwiz/Models`) |
| `mmproj` | optional vision projector GGUF → `--mmproj` |
| `ctx` | context window (tokens) to launch with |
| `port` | listen port |
| `group` | swap-group name. Same port+group = one-at-a-time (swap). Empty = standalone. |
| `vram_mib` | min free VRAM pre-check |
| `cpu_moe` | MoE expert offload: `true`→all experts CPU, a number→that many layers to CPU |
| `ngl` | GPU layers (default 999=all; 0=pure CPU; dense models) |
| `kv` | KV cache type (default `q8_0`; dense long-ctx uses `iq4_nl`) |
| `parallel` | number of slots (`-np`); N slots serve N concurrent sessions from ONE loaded model |
| `embedding` | `true` = dedicated embedding model (`--embedding`) |

**Every model gets TWO variants** (see the YAML header):
- `<id>` — PARALLEL variant (unique port, no group, configurable slots)
- `<id>-swap` — SWAP variant (shared port+group, 1 slot, swaps with siblings)

```bash
model-host start 9b        # parallel, 3 slots, :8081
model-host start 9b-swap   # swap-group qwen9b, 1 slot, :8081
```

**Add a model:** copy any block, fill the fields, run `model-host verify`.

---

## 4. The launcher — `model-host.sh`

Commands:

```bash
model-host start <id>     # start (unloads EVERY other running model first)
model-host stop [<id>]    # stop one, or all
model-host status         # what's running, on which port
model-host log <id>       # tail a server's log
model-host list           # the model table
model-host verify         # validate registry (ids/ggufs/ports)
```

### The swap rule (CRITICAL)

> **ONE MODEL AT A TIME.** `start()` stops **every** other running model (any
> port) before loading the chosen one. No two llama servers coexist on the
> swap host. This is the whole point of swap on a 16 GB GPU.

Implemented in `start()`:

```bash
for m in $(all_models); do
  if [ "$m" != "$model" ] && is_running "$m"; then
    echo "swap: unloading $m …"
    stop_one "$m"
  fi
done
```

`start()` then runs the VRAM pre-check, builds flags from the registry
(`--n-cpu-moe`, `--mmproj`, `-ngl`, KV type, `-np`), and launches via
`llama-run.sh` in the background, waiting up to 90s for "model loaded".

---

## 5. The TUI — `llama-menu`

Launch: `llama-menu` (symlink → `~/.config/llama-containers/llama-menu`).

### Keys

- **Model keys are DOUBLED LETTERS** (`aa`, `bb`, `cc` … `zz`, then `aaa`,
  `bbb`, …) so they never collide with the single-char menu commands.
- **`[e]`** — Stop running models (only the ones actually up)
- **`[s]`** — Stop ALL
- **`[g]`** — GPU monitor (live nvidia-smi + status)
- **`[q]`** — Quit
- Press a model key → `model-host start <id>`.

### Why doubled letters
The old single-char keys (`0–9`, `a–z`) collided with `e/s/g/q` and caused
"Invalid choice". Doubled letters are unambiguous and stable per session.

---

## 6. The gateway — `swap-proxy` (`:8090`)

An OpenAI-compatible endpoint that lets clients (pi, opencode) swap models just
by changing the `model` field. **Native llama.cpp feature**: it serves its
catalog from `llama-models.yaml` (via the `llama-models` CLI), exactly the
models llama-menu manages.

```
GET  /v1/models           → catalog from llama-models.yaml (HTTP 200)
POST /v1/chat/completions → resolve model → model-host start <id>
                            (unloads all others) → forward request
```

- Ops: `~/Ymir/scripts/swap-proxy {start|stop|status|restart}`
- Log: `/tmp/opencode/swap-proxy.log`; pid `/tmp/opencode/swap-proxy.pid`
- **Aliases** (`ALIASES` in `swap-proxy.cjs`): opencode short ids
  (`gemma4-12b-qat-uncensored`) → registry ids (`hauhau-gemma-swap`).
- **One-at-a-time** — NOT for concurrent dual-chat (that needs a dedicated
  `parallel:2` instance, see §8).

### `GET /v1/models` (why it matters)
`opencode /login llama.cpp` validates a provider by fetching `/v1/models`.
The gateway now answers HTTP 200 with the 40-model catalog — no API key needed
for local models; a placeholder (`sk-not-key-required`) is fine.

---

## 7. How pi + opencode connect

- **opencode accounts** (`opencode`, `-rd`, `-work`, `-oczer`): their
  `llama.cpp` provider → `baseURL http://127.0.0.1:8090/v1` (the gateway).
- **pi** (`~/.pi/agent/models.json`): `llamacpp*` providers have
  `_launchCommand: model-host start <id>-swap` and per-model baseUrls — pi
  starts the swap variant itself.

Both end up calling the same swap logic → one model at a time.

---

## 8. Dual-chat — the dedicated exception

The Dojo Dual Chat (`~/CodeP/dojodirector/.dual_chat`) runs TWO opencode web
instances (her, him) on the SAME model `gemma4-12b-qat-uncensored`
**concurrently**. It uses a **dedicated** registry entry:

```
dualchat-gemma   :8098   parallel: 2   (always resident, not in a swap group)
```

her/him opencode define their own `dualchat` provider → `:8098`, bypassing the
one-at-a-time gateway. `-np 2` = one slot per partner. Pointing them at the
swap host caused `AI_APICallError: Loading model`.

---

## 9. Model families (40 registered, Sep 2026)

| Family | Parallel | Swap group | Notes |
|---|---|---|---|
| Qwen3.6-35B-A3B | q2:8125 iq3:8126 q4:8127 q5:8128 | qwen35 :8125 | MoE, `--n-cpu-moe` |
| Qwen3.6-35B-A3B orch | q3:8093 | — | experts on CPU |
| Qwen3.5-9B | 9b:8081 highctx:8082 | qwen9b :8081 | vision |
| Qwen3.5-4B | 4b:8084 | qwen4b :8084 | |
| Qwen3.8-27B | 27b:8083 cpu:8094 | qwen27b :8083 | dense; cpu `ngl:0` |
| Qwen3.8-Flash-Next | q3-flash:8095 | qwen3flash :8095 | 125B MoE, experts CPU, 100K ctx |
| Qwopus-9B-Coder | qwopus:8086 | qwopus9b :8086 | |
| Frontend-8B | frontend:8087 | frontend8b :8087 | |
| Gemma-26B-A4B | gemma:8085 | gemma26b :8085 | |
| Gemma-12B | 12b-q3:8088 q4:8089 | gemma12b :8088 | |
| Gemma4-12B-QAT | hauhau-gemma:8090 | gemma12b :8088 | dual-chat model |
| Gemma4-12B-QAT dual | **dualchat-gemma:8098** | — | 2 slots, dedicated |
| Qwen3.5-9B-Uncensored | hauhau-9b:8091 | qwen9b :8081 | |
| MiniCPM5-1B | minicpm:8092 | minicpm1b :8092 | tiny/fast |
| Nomic Embed | embed:8100 | embeddings :8100 | `--embedding` |

---

## 10. Day-to-day commands

All commands are on PATH via symlinks in `~/.local/bin/` (`llama-menu`,
`model-host`, `llama-models`, **`llama-router`**, **`swap-proxy`**) — run them
from any directory.

```bash
llama-router start / stop / status / restart   # the router (:8080, all models)
llama-menu                              # open the TUI
model-host start dualchat-gemma         # dedicated dual-chat model (:8098, 2 slots)
model-host start q3-flash-swap          # Qwen3.8 Flash Next (experts on CPU)
model-host stop                         # stop everything
model-host status                       # what's running
model-host verify                       # validate registry
swap-proxy status                       # gateway status (:8090, legacy)
```

> **Always start the model host with `llama-router start`, NOT bare `llama
> serve`.** Bare `llama serve` starts a router with only the model cache
> (1 model); `llama-router` regenerates the `--models-preset` INI from
> `llama-models.yaml` (all 23 models).

---

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `AI_APICallError: Loading model` (dual-chat) | both partners on the swap host | use `dualchat` provider → `:8098`; start `dualchat-gemma` |
| `swap failed: model failed to start` | VRAM held by another model | swap rule unloads all first; else `model-host stop` |
| `not enough free VRAM` | a non-swap model (dualchat) resident | expected — stop it, or lower target ctx |
| `/login llama.cpp` → fetch failed | gateway lacked `/v1/models` | now serves catalog (HTTP 200); no API key needed |
| `Invalid choice` (menu) | old single-char keys | doubled letters; restart `llama-menu` |
| OOM at model load | wrong offload config | MoE: `cpu_moe:true`; dense: lower `ngl`; see modeltesting |

---

## Related

- [`how-llama-swap-works.md`](./how-llama-swap-works.md) — research background on model swapping
- [`swap-proxy.md`](./swap-proxy.md) — gateway ops
- [`../models/qwen3.8-flash-next-settings.md`](../models/qwen3.8-flash-next-settings.md) — big-MoE offload
- [`../llamacpp/TESTING.md`](../llamacpp/TESTING.md) — the CUDA llama-server build
- `~/Ymir/docs/zerwizdocs/backupscripts/llama-menu/` — backup copy of every script

---

## 12. Update — all models exposed to pi + gateway (2026-09-07)

**Problem:** pi's `.pi/agent/models.json` only listed 20 llama.cpp `@`-tweaked
variants (`qwen3.6-35b-a3b@q2_k_xl`, …). The llama.cpp registry has **40**
ids (`q2`, `q2-swap`, `9b`, `9b-swap`, `dualchat-gemma`, …) — none of those
were visible in pi, so pi couldn't see/select most models.

**Fix:**
1. **Pi catalog expanded to 60 launchable models.** All 40 registry ids were
   added to `~/.pi/agent/models.json` as `llamacpp-<id>` providers (correct
   port + `model-host start <id>`), on top of the existing 20 @-variants.
   `pi llamacpp launchable models: 60`.
2. **Gateway merges both catalogs.** `swap-proxy.cjs` `buildModelMap()` now
   loads the llama.cpp registry (native) **and** pi's launchable models, so
   `/v1/models` serves all 60 and any id routes to `model-host start <id>`.
3. Command-repo copy + `backupscripts/llama-menu/pi-models.json` synced.

Verified: `/v1/models` → **60 models** (40 registry + 20 @-ids); a registry id
(`minicpm-swap`) swaps correctly through the gateway.