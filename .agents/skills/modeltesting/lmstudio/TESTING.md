# LM Studio Testing — current default backend, JIT + Auto-Evict

Per-backend testing guide for **LM Studio**. This is the **current interim
default** gateway upstream (`:1234`) until the bench proves llama.cpp router
mode, and it has the most ready fleet of our 4 target models. Numbered sections
map to [`../backends-benchmark.md`](../backends-benchmark.md).

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 Laptop **16 GB VRAM**, 122 GiB RAM)
- App: **0.4.20** (0.4.23 available); engine `llama.cpp-linux-x86_64-nvidia-cuda12-avx2@2.32.0` (2.33.0 downloading)
- Server: `:1234` running; `lms ps` currently = nothing loaded
- Status: **default until bench decides; bundled engine known to be slow (§11.1); docs how to test the JIT/Auto-Evict path**

---

## 1. Why this folder matters to the bench

- LM Studio is the **interim default** upstream (`WOT_AI_UPSTREAM_URL → :1234`).
- It's the only backend with **all 4 targets already available** (§12.1):
  `qwen3.6-35b-a3b@q2_k_xl/q4_k_s/q5_k_m/iq3_s`, `qwen3.8-27b`,
  `gemma-4-26b-a4b-it`, `qwen3.5-9b`, …
- **0.4.x JIT** auto-loads an unloaded model when a `/v1/chat/completions`
  arrives (~15 s first load), and **Auto-Evict** frees one when another must
  load — genuine on-demand swap (§12.5).
- Native v1 REST (`/api/v1/models/load`, `/api/v1/models/unload`) lets a wrapper
  set `context_length`, `offload_kv_cache_to_gpu`, `num_experts`,
  `flash_attention`, and a per-model idle **TTL** (auto-unload).

**The catch:** LM Studio is llama.cpp-**based** with a **bundled (lagging)
engine** — 30–52% slower than llama.cpp source on the same GGUF (§11.1), and
the Qwen3.5/3.6 compat quirks hit worst here (§11.2). So LM Studio tests answer:
*is the bundled engine *fast enough* for the fast builds, or must we fall back
to source-built llama-server?*

---

## 2. Current state on this box (§4)

| Item | State |
|---|---|
| App version | 0.4.20 (build 1); **0.4.23 available** |
| Engine | CUDA12 engine 2.32.0 (correct, not CPU); 2.33.0 auto-downloading |
| Server | `:1234`, key session-specific |
| Known flaw | `qwen3.5-9b` at 139K ran **0% GPU util / 8.7 GB flat** during prefill — compute effectively not offloaded / clock-limited |
| `--mlock` | **fails** — `failed to mlock 572129280-byte buffer` (memlock limit 8 MB, §6) |
| Launch flags | near-ideal: `--n-gpu-layers 999999 --flash-attn on --kv-offload --kv-unified --cache-type-k q8_0 --cache-type-v q4_0 --mlock` — but the working set doesn't fit after ~2 GB driver overhead |

The 139K finding: LM Studio's server launches llama-server with near-ideal
flags, but model (7.4 GB) + KV (2.9 GB @139K) ≈ 10.4 GB + driver overhead
doesn't fit → CPU prefill (~100 tok/s). Not a flag bug — a residency problem.

---

## 3. Models to test (from §10 matrix)

Same 4 targets, all already loaded in LM Studio's catalog (§12.1):

| # | Model | Quant ids available | Arch class | Fit 16 GB | Notes |
|---|---|---|---|---|---|
| A | `qwen3.5-9b` | full | dense | yes | default ~139K config over-allocated; tighten |
| B | `qwen3.6-35b-a3b` | `q2_k_xl` / `q4_k_s` / `q5_k_m` / `iq3_s` | **MoE** | Q4 no; Q2/iq3 mostly | bundled engine can't expose `--n-cpu-moe` |
| C | `qwen3.8-27b` | full | hybrid-attn (dense-fit) | yes | verify load before assuming fit |
| D | `gemma-4-26b-a4b-it` | full | **MoE** (A4B) | Q5 no; lower quant yes | Q5 needs spill/low quant |

---

## 4. Driving LM Studio: control via REST / GUI

### Restore a clean baseline (§3/§4)

```bash
# unload whatever is resident (or restart the app; it auto-restarts via systemd)
pkill -f "lm-studio"
sleep 5
nvidia-smi --query-gpu=memory.used --format=csv,noheader   # confirm baseline
```

LM Studio is driven via the GUI or its local API. Note its API endpoints
are **model-management** (`/api/v1/models/load`, `.../unload`); the
completion endpoint is the OpenAI-compatible `/v1/chat/completions`.

### Set a tight per-model config (don't auto-inflate to 139K)

Per-model config keys (mirror the load config): `llm.load.contextLength`,
`offloadKVCacheToGpu`, `num_experts`, `flash_attention`. Set GPU offload to max
(gear icon), Flash Attention on, KV quant on, batch 4096, and keep context to
what you need (§11.5.2).

---

## 5. Benchmark procedure (§3 + §11.5)

Follow the parent doc's procedure. LM Studio specifics:

- **Reset/restart between runs** — the app relaunches via systemd; check for
  lingering processes after `pkill` (§3).
- API `/v1/chat/completions` returns `usage.prompt_tokens` + timing but **not**
  as fine-grained as Ollama's self-report. For real speed use wall-clock
  `completion_tokens / wall_clock` (§3 pitfall 6).
- **Confirm GPU utilization during prefill** with the parallel `nvidia-smi`
  capture loop — this is where the 0%-util CPU-spill failure shows itself.
- Verify GPU offload is actually active (slider at max) via `nvidia-smi`.

Also confirm LM Studio is **not** silently CPU-falling back — the §4.4 symptom
is 0% GPU util during a large prefill.

---

## 6. Expected values / what LM Studio must beat to stay default

- **Bundled lag anchor (§11.1):** LM Studio is 30–52% slower than llama.cpp
  source on the same GGUF (varies by GPU; big on high-end). Its A5000 numbers
  will be well below the llama.cpp §10.4 references.
- **Decision gate (§12.3.2):** can LM Studio's bundled engine run the *fast*
  builds fast enough, or does it force the source llama-server fallback?
- Even if slower, LM Studio stays valuable for **JIT swap convenience** — the
  bench records whether its ~15 s JIT first-load + Auto-Evict makes pi+socket
  on-demand usable.

---

## 7. What to record / outcomes

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified value and reflect the
> processor/VRAM findings, so pi's registry is never stale (§ shared rule 8).

- Fill §10.5 rows A–D at 80K & 100K (gen t/s, prefill t/s, TTFT, VRAM, GPU/CPU%).
- Note where LM Studio **spills to CPU** and the t/s collapse point (the §4
  139K finding predicts this at big context).
- Decision: keep as interim default, or hand the fast lane to llama.cpp router
  mode (§12.5 ranking: native llama.cpp router → LM Studio JIT → Ollama →
  llama-swap)?

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §3 methodology, §4 §3 engine findings, §10 matrix, §11 why the Unsloth GGUFs look slow in LM Studio, §12.5 JIT/Auto-Evict
- `~/.local/bin/lms` — LM Studio CLI (`lms load/unload/ps`)